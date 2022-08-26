module test;
import zconfig;

void main() {}

struct MinMax {
    int min;
    int max;
}

void minMaxHandler(string value, out MinMax confValue)
{
    import std.string : split;
    import std.conv : to;
    auto segments = value.split("-");

    confValue.min = segments[0].to!int;
    confValue.max = segments[1].to!int;
}

unittest
{
    struct MyConfig
    {
        @Handler!minMaxHandler
        MinMax minMax;
    }

    string[] cliArgs = ["foo", "--minMax=5-10"];

    bool helpWanted = false;
    MyConfig conf = initializeConfig!(MyConfig, "Usage")(cliArgs, helpWanted);
    assert(conf.minMax.min == 5);
    assert(conf.minMax.max == 10);
}

