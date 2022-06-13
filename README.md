# zconfig

zconfig is a library that easily serializes and deserializes config files or
directly provide them through the command line based on a given annotated struct.

The library provides annotations which are used on plain old data structs which
give them information such as descriptions or other shortnames.

The actual parsing is not done by this library but is directly feeded into D's
[getopt function](https://dlang.org/phobos/std_getopt.html#.getopt). This library
just parses a config file and generates arguments for getopt out of them.

The benefit by using getopt is that you essentially synchronize the command line
arguments and the config file options with just one struct.

## Annotations
| Annotation | Description |
| --- | --- |
| @Section | Describes a section. When a struct member is annotated with it then the member will be written underneath `[section]`. |
| @Desc | Adds a description to a struct member which will be printed on the command line help and on the config file. |
| @Short | Provide an alternative (short-)name to a struct member. Allows the same setting to be changed via alternative (short-)names. |
| @OnlyCLI | Do not (de-)serialize the struct member but only read it from the command line. |
| @ConfigFile | Mark a struct member to be the filename of the to-be-read config file. This is a special annotation and only be provided to one struct member. It also can only be provided through the command line. |
| @PassThrough | Same as getopt passThrough. |
| @Required | Same as getopt required. If the option is not provided an error is thrown. |
| @Handler | Call a custom handler function for the annotated struct member which is responsible for setting its value. |

## API
| Function | Description |
| --- | --- |
| initializeConfig | Automatically generates the getopt arguments and calls said function with it. |
| getConfigArguments | Parses the config file and creates an args array ouf of them excluding options provided through the command line. |
| writeExampleConfigFile | Creates an example config based on an annotated struct. |

Additional information is written inside the source. Run `dub build docs` to view them in html format.

## Usage
Basic example
```d
struct MyConfig
{
    @ConfigFile @Short("c") @Desc("Read this config file instead of the default.")
    string configFile;
    @Desc("My number.")
    int number;
    @Desc("My bool.")
    bool toggle;

    @Section("service")
    {
        @Required @Short("host") @Desc("Hostname of the service.")
        string hostname = "localhost";
        @Required @Short("p") @Desc("Port of the service.")
        int port = 1234;
    }
}

enum usage = "My program version 1.0 does things.";

int main(string[] args)
{
    string[] configArgs = getConfigArguments!MyConfig("myconf.conf", args);

    if (configArgs.length > 0)
    {
        import std.array : insertInPlace;

        // Prepend them into the command line args
        args.insertInPlace(1, configArgs);
    }

    MyConfig conf;
    bool helpWanted = false;

    import std.getopt : GetOptException;
    try
    {
        conf = initializeConfig!(MyConfig, usage)(args, helpWanted);
    }
    catch (GetOptException e)
    {
        import std.stdio : stderr;
        stderr.writefln("Invalid argument: %s", e.msg);
        return 1;
    }

    if (helpWanted)
    {
        return 0;
    }
}
```
Generate example config file
```d
int main(string[] args)
{
    writeExampleConfigFile!MyConfig("myconf.conf");
    return 0;
}
```
`myconf.conf` will have the following content:
```ini
; My number.
; Default value: 0
;number=0

; My bool.
; Default value: false
;toggle=false

[service]
; Hostname of the service.
; Default value: localhost
;hostname=localhost

; Port of the service.
; Default value: 1234
;port=1234

```

## Handler/Callback example
It is possible to define a custom handler to set a config struct member.  
The following restrictions apply on the handler function:
 - Have two parameters.
 - The first parameter is the string value as given through
   `args` and must therefore have type string.
 - The second parameter must be declared `ref` or `out` and
   must have the same type as the config member. This is the
   config struct's variable the handler is supposed to set.


Here is an example that parses a string (provided through a config file or the CLI arguments) and extracts the `x` and `y` coordinate to set for the config struct.


```d
struct Point
{
    int x;
    int y;
}

void pointHandler(string value, out Point confValue)
{
    import std.string : split;
    import std.conv : to;
    auto segments = value.split("x");

    confValue.x = segments[0].to!int;
    confValue.y = segments[1].to!int;
}

struct MyConfig
{
    @Desc("Defines a point") @Handler!pointHandler
    Point coordinate;
}
```
Calling the program with e.g. `./myapp --coordinate=20x62` will call the `pointHandler` with `value="20x62"`. It will then get split and the respective fields are set with the resulting config file having `MyConfig.coordinate.x = 20` and `MyConfig.coordinate.y = 62`.
