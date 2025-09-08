#include <map>
#include <iostream>
#include <thread>
#include <filesystem>
#include <regex>

#include <nix/expr/eval-settings.hh>
#include <nix/main/shared.hh>
#include <nix/store/store-api.hh>
#include <nix/store/store-open.hh>
#include <nix/expr/eval.hh>
#include <nix/expr/eval-inline.hh>
#include <nix/util/util.hh>
#include <nix/expr/get-drvs.hh>
#include <nix/store/globals.hh>
#include <nix/flake/settings.hh>
#include <nix/cmd/common-eval-args.hh>
#include <nix/flake/flakeref.hh>
#include <nix/flake/flake.hh>
#include <nix/flake/lockfile.hh>
#include <nix/expr/attr-path.hh>
#include <nix/store/derivations.hh>
#include <nix/store/local-fs-store.hh>
#include <nix/util/logging.hh>
#include <nix/util/error.hh>
#include <nix/cmd/installables.hh>
#include <nix/store/path-with-outputs.hh>
#include <nix/cmd/installable-flake.hh>
#include <nix/expr/value-to-json.hh>
#include <nix/expr/eval-gc.hh>

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

std::string attrPathJoin(std::vector<std::string> path) {
    return std::accumulate(path.begin(), path.end(), std::string(),
                           [](std::string ss, std::string s) {
                               // Escape token if containing dots
                               if (s.find(".") != std::string::npos) {
                                   s = "\"" + s + "\"";
                               }
                               return ss.empty() ? s : ss + "." + s;
                           });
}

// Errors as defined src/libexpr/nixexpr.hh, ordered by specifity, descending
static std::string errorToString(nix::Error *error) {
    if (nullptr != dynamic_cast<nix::RestrictedPathError *>(error)) {
        return std::string("RestrictedPathError");
    } else if (nullptr != dynamic_cast<nix::MissingArgumentError *>(error)) {
        return std::string("MissingArgumentError");
    } else if (nullptr != dynamic_cast<nix::UndefinedVarError *>(error)) {
        return std::string("UndefinedVarError");
    } else if (nullptr != dynamic_cast<nix::TypeError *>(error)) {
        return std::string("TypeError");
    } else if (nullptr != dynamic_cast<nix::Abort *>(error)) {
        return std::string("Abort");
    } else if (nullptr != dynamic_cast<nix::ThrownError *>(error)) {
        return std::string("ThrownError");
    } else if (nullptr != dynamic_cast<nix::AssertionError *>(error)) {
        return std::string("AssertionError");
    } else if (nullptr != dynamic_cast<nix::ParseError *>(error)) {
        return std::string("ParseError");
    } else if (nullptr != dynamic_cast<nix::EvalError *>(error)) {
        return std::string("EvalError");
    } else {
        return std::string("Error");
    }
}

struct MyArgs : MixEvalArgs, MixCommonArgs, RootArgs {
    std::string releaseExpr;
    Path gcRootsDir;
    bool flake = false;
    bool quiet = false;
    bool fromArgs = false;
    bool showTrace = false;
    size_t maxFailures = SIZE_MAX;
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

    MyArgs() : MixCommonArgs("nix-unit") {
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

        addFlag({.longName = "max-failures",
                 .description = "fail suite after a certain number of failures",
                 .labels = {"max-failures"},
                 .handler = {&maxFailures}});

        addFlag({.longName = "quiet",
                 .description = "only output results from failing tests",
                 .handler = {&quiet, true}});

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
                PathView here(".");
                // overriden inputs are unlocked
                lockFlags.allowUnlocked = true;
                lockFlags.inputOverrides.insert_or_assign(
                    flake::parseInputAttrPath(inputPath),
                    parseFlakeRef(nix::fetchSettings, flakeRef, absPath(here),
                                  true));
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
        Expr *e =
            state.parseExprFromString(myArgs.releaseExpr, state.rootPath("."));
        state.eval(e, vTop);
    } else {
        state.evalFile(lookupFileArg(state, myArgs.releaseExpr), vTop);
    }

    auto vRoot = state.allocValue();

    state.autoCallFunction(autoArgs, vTop, *vRoot);

    return vRoot;
}

void runDiffTool(std::string diffTool, std::string_view actual,
                 std::string_view expected) {
    AutoDelete tmpDir(createTempDir(), true);
    Path actualPath = (Path)tmpDir + "/actual.nix";
    Path expectedPath = (Path)tmpDir + "/expected.nix";

    writeFile(actualPath, actual);
    writeFile(expectedPath, expected);

    auto res = runProgram(RunOptions{
        .program = "/bin/sh",
        .lookupPath = true,
        .args = {"-c", diffTool + " --color always " + actualPath + " " +
                           expectedPath},
    });
    if (!(WIFEXITED(res.first) &&
          (WEXITSTATUS(res.first) == 0 || WEXITSTATUS(res.first) == 1))) {
        throw ExecError(res.first, "program '%1%' %2%", diffTool,
                        statusToString(res.first));
    }

    std::cerr << res.second << std::endl;
}

struct TestResults {
    int total;
    int success;
    int failures;
};

std::string printValueWithRepated(EvalState &state, Value &v) {
    std::ostringstream out;
    v.print(state, out, PrintOptions{.force = true});
    return out.str();
}

static TestResults runTests(ref<EvalState> state, Bindings &autoArgs) {
    nix::Value *vRoot = [&]() {
        if (myArgs.flake) {
            PathView here(".");
            auto [flakeRef, fragment, outputSpec] =
                parseFlakeRefWithFragmentAndExtendedOutputsSpec(
                    nix::fetchSettings, myArgs.releaseExpr, absPath(here));
            InstallableFlake flake{
                {}, state, std::move(flakeRef), fragment, outputSpec,
                {}, {},    myArgs.lockFlags};

            return flake.toValue(*state).first;
        } else {
            return releaseExprTopLevelValue(*state, autoArgs);
        }
    }();

    const auto expectedErrorNameSym = state->symbols.create("expectedError");
    const auto expectedNameSym = state->symbols.create("expected");
    const auto exprNameSym = state->symbols.create("expr");
    const auto typeNameSym = state->symbols.create("type");
    const auto msgNameSym = state->symbols.create("msg");

    if (vRoot->type() != nAttrs) {
        throw EvalError(*state, "Top level attribute is not an attrset");
    }

    TestResults results = {0, 0, 0};

    // Run a single test from attrset
    const auto runTest = [&](std::vector<std::string> attrPath,
                             nix::Value *test) {
        results.total++;

        std::string attr = attrPathJoin(attrPath);

        try {
            state->forceAttrs(*test, noPos, "while evaluating test");

            if (test->type() != nAttrs) {
                throw EvalError(*state, "Test is not an attrset");
            }

            auto expr = test->attrs()->get(exprNameSym);
            if (!expr) {
                throw EvalError(*state, "Missing attrset key 'expr'");
            }

            auto expectedError = test->attrs()->get(expectedErrorNameSym);
            auto expected = test->attrs()->get(expectedNameSym);

            bool success = false;

            if (expected) {
                state->forceValueDeep(*expr->value);
                state->forceValueDeep(*expected->value);
                success = state->eqValues(*expr->value, *expected->value, noPos,
                                          "while comparing (expr == expected)");

                if (!myArgs.quiet || !success) {
                    (success ? std::cout : std::cerr)
                        << (success ? "✅" : "❌") << " " << attr << std::endl;
                }

                if (!success) {
                    runDiffTool(
                        "difft", printValueWithRepated(*state, *expr->value),
                        printValueWithRepated(*state, *expected->value));
                }

            } else if (expectedError) {
                state->forceAttrs(*expectedError->value, noPos,
                                  "while evaluating expectedError");

                // Get expectedError.type
                std::string expectedErrorType;
                auto expectedErrorTypeAttr =
                    expectedError->value->attrs()->get(typeNameSym);
                if (expectedErrorTypeAttr) {
                    expectedErrorType = state->forceStringNoCtx(
                        *expectedErrorTypeAttr->value, noPos,
                        "while reading \"type\"");
                }

                // Get expectedError.msg
                std::string expectedErrorMsg;
                auto expectedErrorMsgAttr =
                    expectedError->value->attrs()->get(msgNameSym);
                if (expectedErrorMsgAttr) {
                    expectedErrorMsg =
                        state->forceStringNoCtx(*expectedErrorMsgAttr->value,
                                                noPos, "while reading \"msg\"");
                }

                if (expectedErrorType.empty() && expectedErrorMsg.empty()) {
                    throw new EvalError(*state,
                                        "Missing both 'expectedError.msg' & "
                                        "'expectedError.type'");
                }

                bool caught = false;

                try {
                    state->forceValueDeep(*expr->value);
                } catch (nix::Error &e) {
                    caught = true;

                    success = true;

                    if (!expectedErrorType.empty()) {
                        auto thrownErrorType = errorToString(&e);

                        if (thrownErrorType != expectedErrorType) {
                            success = false;
                            std::cerr << "❌ " << attr
                                      << "\nExpected error type '"
                                      << expectedErrorType << "', while '"
                                      << thrownErrorType << "' was thrown\n"
                                      << std::endl;
                        }
                    }

                    if (success && !expectedErrorMsg.empty()) {
                        auto thrownErrorMsg = e.msg();

                        auto pattern = std::regex(expectedErrorMsg);
                        std::cmatch m;
                        if (!std::regex_search(thrownErrorMsg.c_str(), m,
                                               pattern)) {
                            success = false;
                            std::cerr << "❌ " << attr
                                      << "\nExpected error msg pattern '"
                                      << expectedErrorMsg
                                      << "' does not match '" << thrownErrorMsg
                                      << "' was thrown\n"
                                      << std::endl;
                        }
                    }
                }

                if (!caught) {
                    throw new EvalError(
                        *state, "Expected error, but no error was caught");
                }

                if (!myArgs.quiet && success) {
                    std::cout << "✅"
                              << " " << attr << std::endl;
                }

            } else {
                throw EvalError(
                    *state,
                    "Missing attrset keys 'expected' or 'expectedError'");
            }

            if (success) {
                results.success++;
            } else {
                results.failures++;
            }
        } catch (const std::exception &e) {
            std::cerr << "☢️"
                      << " " << attr << "\n"
                      << e.what() << "\n"
                      << std::endl;
        }
    };

    // Recurse into test attrset
    std::function<void(std::vector<std::string>, nix::Value *)> recurseTests;
    recurseTests = [&](std::vector<std::string> attrPath,
                       nix::Value *testAttrs) -> void {
        for (auto &i : testAttrs->attrs()->lexicographicOrder(state->symbols)) {
            const std::string &name = std::string(state->symbols[i->name]);

            // Copy and append current attribute
            std::vector<std::string> curAttrPath = attrPath;
            curAttrPath.push_back(name);

            // Value is a name prefixed by test run test
            if (name.rfind("test", 0) == 0) {
                runTest(curAttrPath, i->value);
                if (myArgs.maxFailures <= results.failures) {
                    throw EvalError(*state, "Hit maximum failures, aborting.");
                }
                continue;
            }

            // If value is an attrset recurse further into tree
            {
                nix::Value *value = i->value;
                state->forceValue(*value, noPos);
                if (value->type() == nAttrs) {
                    recurseTests(curAttrPath, value);
                }
            }
        }
    };

    recurseTests(std::vector<std::string>({}), vRoot);

    return results;
}

int main(int argc, char **argv) {
    return handleExceptions(argv[0], [&]() {
        initNix();
        initGC();
        flakeSettings.configureEvalSettings(evalSettings);

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
        auto evalStore =
            myArgs.evalStoreUrl ? openStore(*myArgs.evalStoreUrl) : openStore();
        auto evalState =
            std::make_shared<EvalState>(myArgs.lookupPath, evalStore,
                                        nix::fetchSettings, nix::evalSettings);

        auto results = runTests(ref<EvalState>(evalState),
                                *myArgs.getAutoArgs(*evalState));

        bool success = results.success == results.total;

        (success ? std::cout : std::cerr)
            << "\n"
            << (results.total == results.success ? "🎉" : "😢") << " "
            << results.success << "/" << results.total << " successful"
            << std::endl;

        if (!success) {
            throw EvalError(*evalState, "Tests failed");
        }
    });
}
