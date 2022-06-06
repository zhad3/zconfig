/**
 * Library that easily serializes and deserializes config files
 * or directly provide them through the command line based on a
 * given annotated struct.
 *
 * Examples:
 * Basic use-case
 * ---
 * struct MyConfig
 * {
 *     @Desc("My number.")
 *     int number;
 *     @Desc("My bool.")
 *     bool toggle;
 * }
 *
 * enum usage = "My program version 1.0 does things.";
 *
 * int main(string[] args)
 * {
 *     string[] configArgs = getConfigArguments!Config("myconf.conf", args);
 *
 *     if (configArgs.length > 0)
 *     {
 *         import std.array : insertInPlace;
 *
 *         // Prepend them into the command line args
 *         args.insertInPlace(1, configArgs);
 *     }
 *
 *     MyConfig conf;
 *     bool helpWanted = false;
 *
 *     import std.getopt : GetOptException;
 *     try
 *     {
 *         conf = initializeConfig!(MyConfig, usage)(args, helpWanted);
 *     }
 *     catch (GetOptException e)
 *     {
 *         import std.stdio : stderr;
 *         stderr.writefln("Invalid argument: %s", e.msg);
 *         return 1;
 *     }
 *
 *     if (helpWanted)
 *     {
 *         return 0;
 *     }
 * }
 * ---
 */
module zconfig;

import std.getopt;

/**
 * Describes a section. When a struct member is annotated
 * with it then the member will be written underneath `[section]`.
 *
 * During parsing the option will also only be valid if it is
 * located underneath said `[section]`. It can also be used
 * as a block annotation. See the examples.
 *
 * Examples:
 * ---
 * struct MyConfig
 * {
 *     @Section("foo") @Desc("My number of foo.")
 *     int number;
 * }
 * ---
 * Will serialize to:
 * ```ini
 * [foo]
 * ; My number of foo.
 * ; Default value: 0
 * ;number=0
 * ```
 *
 * Examples:
 * ---
 * struct MyConfig
 * {
 *     @Desc("My \"global\" option.")
 *     int gNumber = -1;
 *
 *     @Section("bar")
 *     {
 *         @Desc("If true the toggle is activated.")
 *         bool toggleMe;
 *         @Desc("Another number.")
 *         int increment = 1;
 *     }
 * }
 * ---
 * Will serialize to:
 * ```ini
 * ; My "global" option.
 * ; Default value: -1
 * ;gNumber=-1
 *
 * [bar]
 * ; If true the toggle is activated.
 * ; Default value: false
 * ;toggleMe=false
 *
 * ; Another number.
 * ; Default value: 1
 * ;increment=1
 * ```
 */
struct Section
{
    string section;
}

/**
 * Adds a description to the option which will be shown
 * in the command line when `-h` is provided and in the
 * config file.
 *
 * Examples:
 * ---
 * MyConfig
 * {
 *     @Desc("My config option.")
 *     int option;
 * }
 * ---
 * Will be serialized as:
 * ```ini
 * ; My config option.
 * ; Default value: 0
 * ;option=0
 * ```
 */
struct Desc
{
    string description;
}

/**
 * Provides an alternative option name. This is mostly
 * convenient on the command line.
 *
 * The shortname will be added verbatim. This allows
 * to provide multiple alternatives at once.
 * Internally the struct member name and the short name
 * will be simply concatenated with the vertical bar ('|').
 *
 * Examples:
 * ---
 * struct MyConfig
 * {
 *      @Short("v") @Desc("Print verbose messages.")
 *      bool verbose;
 * }
 * ---
 * Allows the usage of `./myapp --verbose` and
 * `./myapp -v`. Both will set the verbose member variable.
 */
struct Short
{
    string shortname;
}

private struct Argument
{
    string section;
    string description;
    string shortname;
    bool onlyCLI = false;
    bool configFile = false;
    bool passThrough = false;
    bool required = false;
}

/// Do not serialize and deserialize this option from the config file.
/// The option will only be available through the command line arguments.
enum OnlyCLI;
/**
 * Special option that allows pointing to another config file (ignoring the default).
 * Can only be provided through the command line arguments. A config struct may only
 * have one ConfigFile annotation. Otherwise an error is thrown.
 *
 * Examples:
 * ---
 * struct MyConfig
 * {
 *     @ConfigFile @Short("c") @Desc("Specific config file to use instead of the default.")
 *     string config = "myconf.conf";
 * }
 * ---
 */
enum ConfigFile;
/// Getopt PassThrough.
enum PassThrough;
/// Getopt Required. If the option is not provided an exception will be thrown.
enum Required;

/**
 * Calls getopt with the provided args array. Usually you want to first call
 * [getConfigArguments] and merge the command line arguments with the config arguments.
 * Which then get passed to this function.
 *
 * The template `ConfigType` is the plain old data struct that
 * describes the options that are used to generate the getopt parameter list.
 * `usage` is used for the [defaultGetoptPrinter] for the usage description when `-h`
 * is provided in the args.
 *
 * Params:
 *   args = The arguments to provide to getopt
 *   helpWanted = if `-h` has been parsed by getopt this out parameter will indicate that
 *
 * Returns:
 *   A fully filled out `ConfigType` struct
 *
 * Examples:
 * ---
 * Only parse command line arguments
 * struct MyConfig
 * {
 *     @Desc("My number.")
 *     int number;
 *     @Desc("My bool.")
 *     bool toggle;
 * }
 *
 * enum usage = "My program version 1.0 does things.";
 *
 * int main(string[] args)
 * {
 *     import std.getopt : GetOptException;
 *
 *     MyConfig conf;
 *     bool helpWanted = false;
 *
 *     try
 *     {
 *         conf = initializeConfig!(MyConfig, usage)(args, helpWanted);
 *     }
 *     catch (GetOptException e)
 *     {
 *         import std.stdio : stderr;
 *         stderr.writefln("Invalid argument: %s", e.msg);
 *         return 1;
 *     }
 *
 *     if (helpWanted)
 *     {
 *         return 0;
 *     }
 * }
 * ---
 */
ConfigType initializeConfig(ConfigType, string usage)(ref string[] args, out bool helpWanted)
{
    ConfigType newConf;
    arraySep = ",";
    mixin(`auto helpInformation = getopt(`, args.stringof,
            generateGetoptArgumentList!(ConfigType, newConf.stringof), `);`);
    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInformation.options);
        helpWanted = true;
    }
    return newConf;
}

private string generateGetoptArgumentList(ConfigType, string configStructName)()
{
    if (__ctfe)
    {
        string arglist = "";
        immutable ConfigType defaultConfig;
        foreach (memberName; __traits(allMembers, ConfigType))
        {
            string attribute = memberName;
            immutable argument = getConfigMemberUDAs!(ConfigType, memberName);
            static if (argument.passThrough)
            {
                arglist ~= `,std.getopt.config.passThrough`;
            }
            static if (argument.required && !argument.passThrough)
            {
                arglist ~= `,std.getopt.config.required`;
            }
            static if (argument.shortname)
            {
                attribute ~= `|` ~ argument.shortname;
            }
            arglist ~= `,"` ~ attribute ~ `"`;
            static if (argument.description)
            {
                import std.conv : to;
                import std.format : format;
                import std.traits : isArray, isSomeString;

                auto member = __traits(getMember, defaultConfig, memberName);
                static if (isArray!(typeof(member)) && !isSomeString!(typeof(member)))
                {
                    string defaultValue = format("%-(%s,%)", member);
                }
                else
                {
                    string defaultValue = member.to!string;
                }

                arglist ~= `,"` ~ argument.description ~ ` Default: ` ~
                    defaultValue ~ `"`;
            }
            arglist ~= ",&" ~ configStructName ~ "." ~ memberName;
        }
        return arglist;
    }
    else
    {
        return "";
    }
}

private Argument getConfigMemberUDAs(ConfigType, string memberName)()
{
    Argument arg;
    foreach (attr; __traits(getAttributes, __traits(getMember, ConfigType, memberName)))
    {
        static if (is(typeof(attr) == Section))
        {
            arg.section = attr.section;
        }
        else static if (is(typeof(attr) == Short))
        {
            arg.shortname = attr.shortname;
        }
        else static if (is(typeof(attr) == Desc))
        {
            arg.description = attr.description;
        }
        else static if (is(attr == OnlyCLI))
        {
            arg.onlyCLI = true;
        }
        else static if (is(attr == ConfigFile))
        {
            arg.configFile = true;
        }
        else static if (is(attr == PassThrough))
        {
            arg.passThrough = true;
        }
        else static if (is(attr == Required))
        {
            arg.required = true;
        }
    }
    return arg;
}

/***
 * Creates an argument array that contains the options provided in
 * the config file.
 *
 * The resulting array contains all provided and valid
 * options excluding ones that were provided through the
 * command line.
 * The template `ConfigType` is the plain old data struct that
 * describes the options that are read from the config filename.
 *
 * Params:
 *   filename = Filename of the config file
 *   args = Command line arguments provided through main(string[] args)
 *
 * Returns: Config exclusive argument array
 *
 * Examples:
 * ---------
 * struct MyConfig
 * {
 *     @Desc("My cool number.")
 *     int number;
 *     @Desc("Print verbose messages.")
 *     bool verbose = false;
 * }
 *
 * int main(string[] args)
 * {
 *     string[] configArgs = getConfigArguments!MyConfig("myconfig.conf", args);
 *
 *     import std.stdio : writeln;
 *     writeln(configArgs);
 * }
 * ---------
 * Assume we have a `myconfig.conf` file that contains the following options:
 * ```ini
 * ; My cool number.
 * number=5
 * ; Print verbose messages.
 * verbose=true
 * ```
 * Calling the above program without any arguments: `./myapp`
 * will print: `["--number", "5", "--verbose", "true"]`.
 *
 * Calling the program with a given argument: `./myapp --number=12`
 * will print: `["--verbose", "true"]`.
 * You can see that our provided `--number=12` has been excluded.
 */
string[] getConfigArguments(ConfigType)(string filename, string[] args)
{
    import std.algorithm : splitter, each, findSplit;
    import std.stdio : File, writeln;
    import std.array : empty, split;

    int[string] identifierMap;
    string[string] shortnameLookupMap;
    bool haveCustomConfigFile = false;
    string configFileMember;
    foreach (memberName; __traits(allMembers, ConfigType))
    {
        immutable argument = getConfigMemberUDAs!(ConfigType, memberName);
        static if (!argument.onlyCLI && !argument.configFile)
        {
            identifierMap[memberName] = 1;
        }
        static if (argument.configFile)
        {
            assert(haveCustomConfigFile == false, "Can only have one config member with the 'ConfigFile' attribute.");
            haveCustomConfigFile = true;
            configFileMember = memberName;
        }
        argument.shortname.splitter('|').each!(name => shortnameLookupMap[name] = memberName);
    }

    int[string] argMap;

    bool argIsConfig = false;
    string configFilename;

    // Create mappings of each option and extract the special 'ConfigFile'
    // value if it was provided. The mappings are used to compare against
    // the values provided in the configuration file.
    foreach (arg; args)
    {
        if (argIsConfig)
        {
            configFilename = arg;
            argIsConfig = false;
            continue;
        }
        import std.string : indexOf;

        auto optionIdentIndex = arg.indexOf(assignChar);
        string optionIdent;
        string optionName;

        if (optionIdentIndex < 0)
        {
            optionIdentIndex = arg.length;
        }

        if (arg.length > 2 && arg[0] == optionChar && arg[1] == optionChar)
        {
            optionIdent = arg[2 .. optionIdentIndex];
            if (optionIdent in shortnameLookupMap)
            {
                optionName = shortnameLookupMap[optionIdent];
                argMap[optionName] = 1;
            }
            else
            {
                optionName = optionIdent;
                argMap[optionIdent] = 1;
            }
        }
        // Check for '-t5' cases where the option 't' has the value '5'
        else if (arg.length > 2 && arg[0] == optionChar && arg[1] != optionChar &&
                (cast(string) [arg[1]]) in shortnameLookupMap)
        {
            optionName = shortnameLookupMap[cast(string) [arg[1]]];
            argMap[optionName] = 1;
        }
        else if (arg.length > 1 && arg[0] == optionChar)
        {
            optionIdent = arg[1 .. optionIdentIndex];
            if (optionIdent in shortnameLookupMap)
            {
                optionName = shortnameLookupMap[optionIdent];
                argMap[optionName] = 1;
            }
            else
            {
                optionName = optionIdent;
                argMap[optionIdent] = 1;
            }
        }
        if (optionName == configFileMember)
        {
            if (optionIdentIndex < arg.length)
            {
                configFilename = arg[optionIdentIndex + 1 .. $];
            }
            else
            {
                argIsConfig = true;
            }
        }
    }

    if (configFilename == configFilename.init)
    {
        configFilename = filename;
    }

    import std.exception : ErrnoException;
    import std.stdio : stderr;

    string[string] confMap;
    File inFile;

    try
    {
        inFile = File(configFilename, "r");
    }
    catch (ErrnoException e)
    {
        stderr.writefln("Error opening config file: %s", e.msg);
        return [];
    }

    scope (exit)
        inFile.close();

    foreach (line; inFile.byLine())
    {
        if (line.empty || line[0] == ';')
        {
            continue;
        }
        if (auto splitted = line.findSplit([assignChar]))
        {
            // Only keep the values if there wasn't a command line argument
            // with the same identifier
            if (cast(const string) splitted[0] in identifierMap &&
                    !(cast(const string) splitted[0] in argMap))
            {
                const key = splitted[0].dup;
                confMap[key] = splitted[2].dup;
            }
        }
    }

    const confKeys = confMap.keys();
    string[] additionalConfArgs;
    additionalConfArgs.reserve(confKeys.length);
    foreach (name; confKeys)
    {
        import std.utf : toUTF8;

        additionalConfArgs ~= [[optionChar].toUTF8 ~ [optionChar].toUTF8 ~ name, confMap[name]];
    }

    return additionalConfArgs;
}

unittest
{
    struct MyConfig
    {
        @Desc("My cool number.")
        int number;
        @Desc("Print verbose messages.")
        bool verbose = false;
    }

    string[] cliArgs = ["--number=5"];
    string[] configArgs = getConfigArguments!MyConfig("test-conf/test.conf", cliArgs);

    import std.conv : to;

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");
}

unittest
{
    struct MyConfig
    {
        @ConfigFile @Short("c") @Desc("Alternative config file")
        string config;
        @Desc("My cool number.")
        int number;
        @Desc("Print verbose messages.")
        bool verbose = false;
    }

    string[] cliArgs = ["--number=5", "-c", "test-conf/test.conf"];
    string[] configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    import std.conv : to;

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");

    // --- Config as last argument

    cliArgs = ["--number=5", "-c", "test-conf/test.conf"];
    configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    import std.conv : to;

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");

    // -- Config as last argument with long name and no space

    cliArgs = ["--number=5", "--config=test-conf/test.conf"];
    configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    import std.conv : to;

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");

    // -- Config does not exist

    cliArgs = ["--number=5", "-c", "i_do_not_exist.conf"];
    configArgs = getConfigArguments!MyConfig("test-conf/test.conf", cliArgs);

    assert(configArgs.length == 0);

    // -- Config as first argument with long name and no space

    cliArgs = ["--config=test-conf/test.conf", "--number=5"];
    configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");

    // -- Config as first argument

    cliArgs = ["-c", "test-conf/test.conf", "--number=5"];
    configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");

    // -- Use last provided config name

    cliArgs = ["-c", "i_also_do_not_exist.conf", "--number=5", "-c", "test-conf/test.conf"];
    configArgs = getConfigArguments!MyConfig("i_do_not_exist.conf", cliArgs);

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--verbose");
    assert(configArgs[1] == "false");
}

unittest
{
    struct MyConfig
    {
        @Short("t")
        int timeout;
    }

    string[] cliArgs = ["-t10"];
    string[] configArgs = getConfigArguments!MyConfig("test-conf/test-short.conf", cliArgs);

    assert(configArgs.length == 0);

    // --

    cliArgs = ["-t 5"];
    configArgs = getConfigArguments!MyConfig("test-conf/test-short.conf", cliArgs);

    assert(configArgs.length == 0);

    // --

    cliArgs = [];
    configArgs = getConfigArguments!MyConfig("test-conf/test-short.conf", cliArgs);

    assert(configArgs.length == 2);
    assert(configArgs[0] == "--timeout");
    assert(configArgs[1] == "200");
}

/**
 * Writes an example config file to the provided filename.
 * If a struct member does not provide a default value then
 * .init is used as the default value.
 *
 * The only exception being arrays which would normally
 * default to '[]' are instead simply left blank. If an array
 * provides a default list then they are printed comma separated.
 * The reason is that getopt expects such format instead of the
 * brackets.

 * Params:
 *   filename = Filename to write the example config file to
 */
void writeExampleConfigFile(ConfigType)(const string filename)
{
    import std.stdio : File;
    import std.format : formattedWrite, format;
    import std.string : wrap;
    import std.array : appender;
    import std.conv : to;
    import std.traits : isArray, isSomeString;

    string currentSection = "";
    immutable ConfigType defaultConfig;
    auto outFile = File(filename, "w+");
    scope (exit)
        outFile.close();
    auto app = appender!string;

    foreach (memberName; __traits(allMembers, ConfigType))
    {
        immutable argument = getConfigMemberUDAs!(ConfigType, memberName);
        if (argument.onlyCLI == true || argument.configFile)
        {
            continue;
        }
        if (currentSection != argument.section)
        {
            currentSection = argument.section;
            app.formattedWrite("[%s]\n", currentSection);
        }
        static if (argument.description)
        {
            app.formattedWrite("%s", wrap(argument.description, 80, "; ", "; "));
        }

        auto member = __traits(getMember, defaultConfig, memberName);
        static if (isArray!(typeof(member)) && !isSomeString!(typeof(member)))
        {
            string defaultValue = format("%-(%s,%)", member);
        }
        else
        {
            string defaultValue = member.to!string;
        }
        app.formattedWrite("; Default value: %s\n", defaultValue);
        app.formattedWrite(";%s=%s\n", memberName, defaultValue);
        app ~= "\n";
    }
    outFile.write(app.data);
}
