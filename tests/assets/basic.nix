{
  testPass = {
    expr = 1;
    expected = 1;
  };

  testFail = {
    expr = { x = 1; };
    expected = { y = 1; };
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
}
