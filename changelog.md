# Change log

## 0.0.8
- Implement support for LaTeX math mode notation
- Now syntax errors would render with dynamic error highlighting instead of static error place holder
- Special thanks to Tomáš Sláma(slama.dev) for testing.

## 0.0.7
- Fix crashing at the start in some setups.

## 0.0.6
- Implement macro update detection so you do not have to delete cache after updating macros.
- Log number of updated macros during project loading configuration.
- Optimization of loading saved cache and rendering.
- Now printing relative path to project of file containing syntax error.
- Major refactoring and better commenting of code.
- Fix all rendering issues being treated as syntax errors. Now render issues are much finer and informative.
- Now you can set cache path as a non-existent (possibly nested) directory and Jektex will create them.

## 0.0.5
- Redesign configuration. Now it is more intuitive and cleaner.
- Make new option for ignoring specific files.
- Add new `jektex` tag for enabling/disabling Jektex rendering in front matter.

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
