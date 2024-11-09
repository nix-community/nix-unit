{
  testPass = {
    expr = 1;
    expected = 1;
  };

  testFail = {
    expr = {
      x = 1;
    };
    expected = {
      y = 1;
    };
  };

  testFailEval = {
    expr = throw "NO U";
    expected = 0;
  };

  nested = {
    testFoo = {
      expr = "bar";
      expected = "bar";
    };
  };

  testCatchThrow = {
    expr = throw "I give up";
    expectedError.type = "ThrownError";
  };

  testCatchAbort = {
    expr = abort "Just no";
    expectedError.type = "Abort";
  };

  testCatchMessage = {
    expr = throw "Still about 100 errors to go";
    expectedError.type = "ThrownError";
    expectedError.msg = "\\d+ errors";
  };

  testCatchWrongMessage = {
    expr = throw "I give up";
    expectedError.type = "ThrownError";
    expectedError.msg = "\\d+ errors";
  };
}
