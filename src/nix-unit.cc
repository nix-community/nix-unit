#include <map>
#include <iostream>
#include <thread>
#include <filesystem>

#include <nix/config.h>
#include <nix/shared.hh>
#include <nix/store-api.hh>
#include <nix/eval.hh>
#include <nix/eval-inline.hh>
#include <nix/util.hh>
#include <nix/get-drvs.hh>
#include <nix/globals.hh>
#include <nix/common-eval-args.hh>
#include <nix/flake/flakeref.hh>
#include <nix/flake/flake.hh>
#include <nix/attr-path.hh>
#include <nix/derivations.hh>
#include <nix/local-fs-store.hh>
#include <nix/logging.hh>
#include <nix/error.hh>
#include <nix/installables.hh>
#include <nix/path-with-outputs.hh>
#include <nix/installable-flake.hh>

#include <nix/value-to-json.hh>

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>

#include <nlohmann/json.hpp>

using namespace nix;
using namespace nlohmann;

// Safe to ignore - the args will be static.
#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#elif __clang__
#pragma clang diagnostic ignored "-Wnon-virtual-dtor"
#endif

struct MyArgs : MixEvalArgs, MixCommonArgs {
    std::string releaseExpr;
    Path gcRootsDir;
    bool flake = false;
    bool fromArgs = false;
    bool showTrace = false;
    bool impure = false;
    bool forceRecurse = false;
    bool checkCacheStatus = false;
    size_t nrWorkers = 1;
    size_t maxMemorySize = 4096;

    // usually in MixFlakeOptions
    flake::LockFlags lockFlags = {.updateLockFile = false,
                                  .writeLockFile = false,
                                  .useRegistries = false,
                                  .allowUnlocked = false};

    MyArgs() : MixCommonArgs("nix-run-tests") {
        addFlag({
            .longName = "help",
            .description = "show usage information",
            .handler = {[&]() {
                printf("USAGE: nix-unit [options] expr\n\n");
                for (const auto &[name, flag] : longFlags) {
                    if (hiddenCategories.count(flag->category)) {
                        continue;
                    }
                    printf("  --%-20s %s\n", name.c_str(),
                           flag->description.c_str());
                }
                ::exit(0);
            }},
        });

        addFlag({.longName = "impure",
                 .description = "allow impure expressions",
                 .handler = {&impure, true}});

        addFlag({.longName = "gc-roots-dir",
                 .description = "garbage collector roots directory",
                 .labels = {"path"},
                 .handler = {&gcRootsDir}});

        addFlag({.longName = "flake",
                 .description = "build a flake",
                 .handler = {&flake, true}});

        addFlag({.longName = "show-trace",
                 .description =
                     "print out a stack trace in case of evaluation errors",
                 .handler = {&showTrace, true}});

        addFlag({.longName = "expr",
                 .shortName = 'E',
                 .description = "treat the argument as a Nix expression",
                 .handler = {&fromArgs, true}});

        // usually in MixFlakeOptions
        addFlag({
            .longName = "override-input",
            .description =
                "Override a specific flake input (e.g. `dwarffs/nixpkgs`).",
            .category = category,
            .labels = {"input-path", "flake-url"},
            .handler = {[&](std::string inputPath, std::string flakeRef) {
                // overriden inputs are unlocked
                lockFlags.allowUnlocked = true;
                lockFlags.inputOverrides.insert_or_assign(
                    flake::parseInputPath(inputPath),
                    parseFlakeRef(flakeRef, absPath("."), true));
            }},
        });

        expectArg("expr", &releaseExpr);
    }
};
#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#elif __clang__
#pragma clang diagnostic ignored "-Wnon-virtual-dtor"
#endif

static MyArgs myArgs;

static Value *releaseExprTopLevelValue(EvalState &state, Bindings &autoArgs) {
    Value vTop;

    if (myArgs.fromArgs) {
        Expr *e = state.parseExprFromString(
            myArgs.releaseExpr, state.rootPath(CanonPath::fromCwd()));
        state.eval(e, vTop);
    } else {
        state.evalFile(lookupFileArg(state, myArgs.releaseExpr), vTop);
    }

    auto vRoot = state.allocValue();

    state.autoCallFunction(autoArgs, vTop, *vRoot);

    return vRoot;
}

struct TestResults {
    int total;
    int success;
};

static TestResults runTests(ref<EvalState> state, Bindings &autoArgs) {
    nix::Value *vRoot = [&]() {
        if (myArgs.flake) {
            auto [flakeRef, fragment, outputSpec] =
                parseFlakeRefWithFragmentAndExtendedOutputsSpec(
                    myArgs.releaseExpr, absPath("."));
            InstallableFlake flake{
                {}, state, std::move(flakeRef), fragment, outputSpec,
                {}, {},    myArgs.lockFlags};

            return flake.toValue(*state).first;
        } else {
            return releaseExprTopLevelValue(*state, autoArgs);
        }
    }();

    auto expectedNameSym = state->symbols.create("expected");
    auto exprNameSym = state->symbols.create("expr");

    if (vRoot->type() != nAttrs) {
        throw EvalError("Top level attribute is not an attrset");
    }

    TestResults results = {0, 0};

    for (auto &i : vRoot->attrs->lexicographicOrder(state->symbols)) {
        const std::string &name = state->symbols[i->name];

        results.total++;

        try {
            auto test = i->value;
            state->forceAttrs(*test, noPos, "while evaluating test");

            if (test->type() != nAttrs) {
                std::cout << test->type() << std::endl;
                throw EvalError("Test is not an attrset");
            }

            auto expected = test->attrs->get(expectedNameSym);
            if (!expected) {
                throw EvalError("Missing attrset key 'expected'");
            }

            auto expr = test->attrs->get(exprNameSym);
            if (!expr) {
                throw EvalError("Missing attrset key 'expr'");
            }

            bool success =
                state->eqValues(*expr->value, *expected->value, noPos,
                                "while comparing (expr == expected)");
            std::cout << (success ? "✅" : "❌") << " " << name << std::endl;

            if (success) {
                results.success++;
            }
        } catch (const std::exception &e) {
            std::cout << "☢️"
                      << " " << name << std::endl;
            printError(e.what());
        }
    }

    return results;
}

int main(int argc, char **argv) {
    return handleExceptions(argv[0], [&]() {
        initNix();
        initGC();

        myArgs.parseCmdline(argvToStrings(argc, argv));

        /* FIXME: The build hook in conjunction with import-from-derivation is
         * causing "unexpected EOF" during eval */
        settings.builders = "";

        /* Prevent access to paths outside of the Nix search path and
           to the environment. */
        evalSettings.restrictEval = false;

        /* When building a flake, use pure evaluation (no access to
           'getEnv', 'currentSystem' etc. */
        if (myArgs.impure) {
            evalSettings.pureEval = false;
        } else if (myArgs.flake) {
            evalSettings.pureEval = true;
        }

        if (myArgs.releaseExpr == "")
            throw UsageError("no expression specified");

        if (myArgs.gcRootsDir == "") {
            printMsg(lvlError, "warning: `--gc-roots-dir' not specified");
        } else {
            myArgs.gcRootsDir = std::filesystem::absolute(myArgs.gcRootsDir);
        }

        if (myArgs.showTrace) {
            loggerSettings.showTrace.assign(true);
        }

        auto evalState = std::make_shared<EvalState>(
            myArgs.searchPath, openStore(*myArgs.evalStoreUrl));

        auto results = runTests(ref<EvalState>(evalState),
                                *myArgs.getAutoArgs(*evalState));

        std::cout << "\n"
                  << (results.total == results.success ? "🎉" : "😢") << " "
                  << results.success << "/" << results.total << " successful"
                  << std::endl;

        if (results.success != results.total) {
            throw EvalError("Tests failed");
        }
    });
}
