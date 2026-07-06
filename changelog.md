# Change log

## 0.2.0
- Major internal rewrite into small tested classes (Config, Renderer, Cache, Processor, Reporter) with a full unit test suite.
- New `katex_options` config key that passes any KaTeX rendering option (like `trust`, `output` or `strict`) directly to KaTeX viz. [docs](https://katex.org/docs/options). Changing them invalidates the cache automatically.
- Fix `jektex: false` in front matter being ignored. Boolean values now disable rendering, quoted `"false"` keeps working.
- Expressions inside code blocks, inline code, `{% highlight %}` tags and similar are no longer rendered. LaTeX in code samples now stays as written, matching the behavior of KaTeX's client side auto-render ([#5](https://github.com/yagarea/jektex/issues/5)).
- Formulas in kramdown notation (`$$..$$`) inside raw HTML blocks like `<div>` are now rendered ([#7](https://github.com/yagarea/jektex/issues/7)). Kramdown skips markdown processing there, so they previously stayed literal. Only markdown source files are affected. A formula alone on its line renders in display mode, inside text flow inline; `\$$` escapes rendering.
- Formulas no longer break when indented or placed in markdown structures like lists, so the `{::nomarkdown}` workaround is not needed anymore.
- Fix number of loaded macros being reported one too high.
- Fix `silent` option not silencing all output.
- Render statistics are now accurate: expressions loaded from cache are counted separately from newly rendered ones.
- A corrupt cache file no longer crashes the build. The cache is rebuilt instead and cache writes are now atomic.
- Cache resets itself automatically when the KaTeX version or a render-affecting option (like `trust`) changes, so it can never serve outdated output. Because of this new cache format, the first build after upgrading re-renders everything once.
- Faster startup: the KaTeX bundle is compiled on first use instead of at load time.
- Much faster first builds: all new expressions of a page are rendered in a single KaTeX call instead of one call per expression (measured around 5-10x faster with node/bun).
- Pages without any math are skipped without work and progress output is throttled, so large cached builds are not slowed down by console printing.

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
