# yu.sh

`yu.sh` stands for Yanzi Utilities in POSIX Shell. The library provides a number
of functions and modules that can be sourced in target scripts. All functions
and variables that are part of the `yu.sh` library are led by, respectively the
`yush_` and `YUSH_` keywords. `yu.sh` also provides a few utilities. `yu.sh`
should normally work on MacOS. Feel free to open [issues] for improvement
suggestions or bug reports.

`yu.sh` is usually best used as a git [submodule].

  [issues]: https://github.com/YanziNetworks/yu.sh/issues
  [submodule]: https://git-scm.com/book/en/v2/Git-Tools-Submodules

Currently, `yu.sh` is composed of the following modules:

+ [log.sh] a library for controlled logging, offering various levels
+ [date.sh] a library to convert back and forth between human-readable periods
  and seconds, and to convert some date formats not always supported by the
  `date` command.
+ [json.sh] a library to parse JSON, slightly modified from the fantastic
  [original](https://github.com/rcrowley/json.sh)
+ [text.sh] a library to provide higher-level textual operations.
+ [file.sh] a library to operate on files and paths

  [log.sh]:./log.sh
  [date.sh]:./date.sh
  [json.sh]:./json.sh
  [text.sh]:./text.sh
  [file.sh]:./file.sh

## Testing

This library can be tested using [bats]. From the [test](./test) directory, run
the following command:

```shell
docker run -it -v "$(pwd):/yu.sh" bats/bats -t /yu.sh/test
```

  [bats]: https://github.com/bats-core/bats-core
