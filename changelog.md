# Change log

## 0.0.6
- Implement upgrade macro detection so you do not have to delete cache after updating macros.
- Log number of updated macros during project loading configuration.
- Optimisation of loading saved cache and rendering.
- Now printing relative path to project of file containing syntax error.
- Major refactoring and better commenting of code.
- Fix all rendering issues being treated as syntax errors. Now render issues are much finer and informative.
- Now you can set cache path throw several nested not existing directories and jektex will create them.

## 0.0.5
- Redesign configuration. No it is more intuitive and cleaner.
- Make new option for ignoring specific files.
- Adds new `jektex` tag for enabling/disabling jektex rendering in front matter.

## 0.0.4
- Make cache location configurable.
- Some bug fixes related to rendering skipping some files.

## 0.0.3
- Make rendering hooks work universally on all pages by default.
- Special thanks to Prokop Randáček (rdck.dev) for testing.

## 0.0.2
- Gem is published.

## 0.0.1
- Name reservation.
