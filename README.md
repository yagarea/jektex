[![Gem Version](https://badge.fury.io/rb/jektex.svg)](https://rubygems.org/gems/jektex)

# ![Jektex](https://blackblog.cz/assets/img/projects/jektex.svg)
A Jekyll plugin for blazing-fast server-side cached LaTeX rendering, with support for macros.
Enjoy the comfort of LaTeX and Markdown without cluttering your site with bloated JavaScript.

## Features
- Renders LaTeX formulas during Jekyll rendering
- Works without any client-side JavaScript
- Is faster than any other server-side Jekyll LaTeX renderer
- Supports user-defined global macros
- Has I/O-efficient caching system
- Dynamically informs about the number of expressions during rendering
- Is very easy to setup
- Doesn't interfere with Jekyll workflow and project structure
- Marks invalid expressions in document, printing its location during rendering
- Is highly configurable with sensible defaults
- Makes sure that cache does not contain expression rendered with outdated configuration
- Supports two major LaTeX notations

## Usage
Jektex supports both the built-in Kramdown math notation, and the newer LaTeX-only math notation.

### Kramdown notation
**Inline formula**  
Put formula between two pairs of dolar signs (`$$`) inside of paragraph.
```latex
Lorem ipsum dolor sit amet, consectetur $$e^{i\theta}=\cos(\theta)+i\sin(\theta)$$
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
```

**Display formula**  
Put formula between two pairs of dolar sings (`$$`) and surround it with two empty lines.
```latex
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.

$$ \left[ \frac{-\hbar^2}{2\mu}\nabla^2 + V(\mathbf{r},t)\right] \Psi(\mathbf{r},t) $$

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
ea commodo consequat.
```

_Why Jektex does not use conventional single `$` for inline formulas and double `$$` for
display mode?  
This is how [kramdown](https://kramdown.gettalong.org/) (Jekyll's markdown parser) works 
so I decided to respect this convention. It makes this plugin more consistent and universal._


### LaTex math mode notation
**Inline formula**  
Put formula between two escaped brackets `\(` `\)`.
Its position in the text does not matter.
```latex
Lorem ipsum dolor sit amet, consectetur \(e^{i\theta}=\cos(\theta)+i\sin(\theta)\)
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
```

**Display formula**  
Put formula between two escaped square brackets `\[` `\]`.
Its position in the text does not matter.
```latex
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.

\[ \left[ \frac{-\hbar^2}{2\mu}\nabla^2 + V(\mathbf{r},t)\right] \Psi(\mathbf{r},t) \]

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
ea commodo consequat.
```

### Logo macro
There is a build in macro for jektex logo. You can use it as `\jektex`.

### Config
Jektex si highly configurable via your `_config.yml` file.

**Disabling cache**  
You can disable caching with `disable_disk_cache = true` in `_config.yml`.
Caching is enabled by default.
You can find more information on [Jekyll's official website](https://jekyllrb.com/docs/configuration/options/).

**Setting cache location**  
By default, Jektex cache will be saved in `.jekyll-cache` directory.
This results in its deletion when you call `jekyll clean`.
To prevent cache deletion or to change the cache location, you can specify `cache_dir` in `_config.yml`:
```yaml
jektex:
  cache_dir: ".jektex-cache"
```

**Ignoring files**  
By default, Jektex tries to render LaTeX in all files rendered by Jekyll.
This can sometimes be undesirable, for example when rendering an _RSS feed_ with excerpts containing LaTeX.
Jektex solves this by using the `ignore` option:
```yaml
jektex:
  ignore: ["*.xml", "README.md", "_drafts/*" ]
```

You can use conventional wild cards using `*`.
This example configuration ignores all `.xml` files, `README.md` and all files in the `_drafts` directory.

Another way to ignore specific posts is setting the `jektex` attribute in front matter to `false`:
```yaml
---
title: "How Jektex works"
category: "Development"
jektex: false
layout: post
---
```

Setting `jektex` tag to `true` or not setting at all will result in Jektex rendering LaTeX expressions in that post.

**Using macros**  
You can define global macros:
```yaml
jektex:
  macros:
    - ["\\Q", "\\mathbb{Q}"]
    - ["\\C", "\\mathbb{C}"]
```
And yes, you have to escape the backlash (`\`) with another backlash.
This is due to the [yaml specification](https://yaml.org/).

**Silencing Jektex output**  
Jektex periodically informs the user about rendered/cached equations.
If this is not desired, you can set the `silent` option (`false` by default).
```yaml
jektex:
  silent: true
```

**Complete examples**  
Recommended config:
```yaml
jektex:
  cache_dir: ".jektex-cache"
  ignore: ["*.xml"]
  silent: false
  macros:
    - ["\\Q", "\\mathbb{Q}"]
    - ["\\C", "\\mathbb{C}"]
```

Having no configuration is equivalent to this:
```yaml
jektex:
  cache_dir: ".jekyll-cache"
  ignore: []
  silent: false
  macros: []
```

## Installation
This plugin is available as a [RubyGem](https://rubygems.org/gems/jektex).

**Using bundler**  
Add Jektex to your `Gemfile`:
```ruby
group :jekyll_plugins do
    gem "jektex"
end
```

and run `bundle install`

**Without bundler**  
Run `gem install jektex`

**After installation**  
Add Jektex to your plugin list in your `_config.yml` file
```yaml
plugins:
    - jektex
```

and don't forget to add `katex.min.css` to you HTML head:
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.15.2/dist/katex.min.css" integrity="sha384-MlJdn/WNKDGXveldHDdyRP1R4CTHr3FeuDNfhsLPYrq2t0UBkUdK2jyTnXPEK1NQ" crossorigin="anonymous">
```
It is much better practice to download the [**css** file](https://cdn.jsdelivr.net/npm/katex@0.15.2/dist/katex.min.css) and load it as an asset from your server directly.
You can find more information on [KaTeX's website](https://katex.org/docs/browser.html).

## Contributions and bug reports
Feel free to report any bugs or even make feature request in [issues on official repository](https://github.com/yagarea/jektex/issues).
I am opened for pull requests as well.

