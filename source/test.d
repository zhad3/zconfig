module test;

import zconfig;

void main() {}

void maxValueHandler(string value, out int confValue)
{
    confValue = 200;
}

unittest
{
    struct MyConfig
    {
        @Handler!maxValueHandler
        int maxValue;
    }

    string[] cliArgs = ["foo", "--maxValue=10"];

    bool helpWanted = false;
    MyConfig conf = initializeConfig!(MyConfig, "Usage")(cliArgs, helpWanted);
    assert(conf.maxValue == 200);
}
