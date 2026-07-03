# Change log

## 0.2.0
- Major internal rewrite into small tested classes (Config, Renderer, Cache, Processor, Reporter) with a full unit test suite.
- New `trust` option in config that enables adverse behavior viz. [docs](https://katex.org/docs/options).
- Fix `jektex: false` in front matter being ignored. Boolean values now disable rendering, quoted `"false"` keeps working.
- Fix number of loaded macros being reported one too high.
- Fix `silent` option not silencing all output.
- Render statistics are now accurate: expressions loaded from cache are counted separately from newly rendered ones.
- A corrupt cache file no longer crashes the build. The cache is rebuilt instead and cache writes are now atomic.
- Cache resets itself automatically when the KaTeX version or a render-affecting option (like `trust`) changes, so it can never serve outdated output. Because of this new cache format, the first build after upgrading re-renders everything once.
- Faster startup: the KaTeX bundle is compiled on first use instead of at load time.

## 0.1.1
- Update KaTeX to 0.16.9 (It is recommended to update your KaTeX css to prevent visual glitches.)
- Added support for bun.sh
- Update documentation
- Fix bug when build in macros were counted as user defined macros
- Small optimizations

## 0.1.0
- Add a silent option to suppress Jektex output.
- Add jektex logo as macro (`\jektex`).
- Fix bug when in obscure cases Latex notation would not be encoded as valid HTML entities.
- Fix bug when Jekyll tries rerendering its own cache resulting in endless loop.
- Update KaTeX to version 0.16.3.
- Remake dependencies for Debian packages compatibility
- Optimization and stability improvement

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
