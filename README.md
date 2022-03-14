# Jektex
Jekyll plugin for blazing fast server side cached LaTeX rendering with support of macros.
Enjoy comfort of latex and markdown without cluttering your site with bloated javascript.

## Features
- Renders LaTeX formulas during Jekyll rendering
- Works without any javascript on clients side
- Is faster than any other server side Jekyll latex renderer
- Supports user defined global macros
- Has I/O efficient caching system
- Has dynamic and informative log during rendering
- Is easy to setup
- Does not interfere with Jekyll workflow and project structure
- Marks invalid syntax in document
- Prints location of invalid expression during rendering
- Highly configurable but still having sensible defaults
- Makes sure that cache does not contain expression rendered with outdated configuration

## Usage

### Notation
**Inline formula**  
Put formula between two pairs of dolar signs (`$$`) inside of paragraph.
```latex
Lorem ipsum dolor sit amet, consectetur $$e^{i\theta}=\cos(\theta)+i\sin(\theta)$$
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
```

**Display formula**  
Put formula between two pairs of dolar sings (`$$`) and surround it by two empty lines.
```latex
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.

$$ \left[ \frac{-\hbar^2}{2\mu}\nabla^2 + V(\mathbf{r},t)\right] \Psi(\mathbf{r},t) $$

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
ea commodo consequat.
```

_Why Jektex does not use conventional single `$` for inline formulas and double `$$` for
display mode?  
This is how [kramdown](https://kramdown.gettalong.org/)(Jekyll's markdown parser) works 
so I decided to respect this convention. It makes this plugin more consistent and universal._

### Config
Jektex si highly configurable from your `_config.yml` file

**Disabling cache**  
You can disable caching with `disable_disk_cache = true` in `_config.yml`. Cache is
enabled by default. You can find more information on [Jekyll official website](https://jekyllrb.com/docs/configuration/options/).

**Setting cache location**  
By default jektex cache will be saved in `.jekyll-cache` directory. This results in it's
deletion when you call `jekyll clean`. To prevent cache deletion or you just want to
change location of cache for another reason you can achieve that by specifying
`cache_dir` in `_config.yml`.
```yaml
# Jektex cache dir location
jektex:
  cache_dir: ".jektex-cache"
```

**Ignore**  
By default jektex tries to render LaTeX in all files not excluded by Jekyll. But 
sometimes you get in situation when you do not want to render some files. For example
_RSS feed_ with excerpts containing LaTeX. As a solution jektex offers `ignore` option.
You can use conventional wild cards using `*`. For example:
```yaml
# Jektex ignore files
jektex:
  ignore: ["*.xml", "README.md", "_drafts/*" ]
```

This example configuration ignores all `.xml` files, `README.md` and all files 
in `_drafts` directory.

Another option for ignoring specific posts is setting `jektex` tag in front matter of
post to `false`. For example:
```yaml
---
title: "How Jektex works"
category: "Development"
jektex: false
layout: post
---
```

Setting `jektex` tag to `true` or not setting at all will result in jektex rendering LaTeX
expressions in that post.

**Macros**  
You can define global macros like this:
```yaml
# Jektex macros
jektex:
  macros:
    - ["\\Q", "\\mathbb{Q}"]
    - ["\\C", "\\mathbb{C}"]
```
And yes you have to escape backlash(`\`) with another backlash. This is caused by
[yaml definition](https://yaml.org/).

**Complete examples**  
Recommended config:
```yaml
jektex:
  cache_dir: ".jektex-cache"
  ignore: ["*.xml"]
  macros:
    - ["\\Q", "\\mathbb{Q}"]
    - ["\\C", "\\mathbb{C}"]
```
Having no configuration is equivalent to this:
```yaml
jektex:
  cache_dir: ".jekyll-cache"
  ignore: []
  macros: []
```

## Installation
This plugin is available as a [RubyGem](https://rubygems.org/gems/jektex).

**Using bundler**  
Add `jektex` to your `Gemfile` like this:
```ruby
group :jekyll_plugins do
    gem "jektex"
end
```

and run `bundle install`

**Without bundler**  
Just run `gem install jektex`

**After installation**  
Add jektex to your plugin list in your `_config.yml` file:
```yaml
plugins:
    - jektex
```

and do not forget to add `katex.min.css` to you html head:
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.15.2/dist/katex.min.css" integrity="sha384-MlJdn/WNKDGXveldHDdyRP1R4CTHr3FeuDNfhsLPYrq2t0UBkUdK2jyTnXPEK1NQ" crossorigin="anonymous">
```
It is much better practice to download [**css** file](https://cdn.jsdelivr.net/npm/katex@0.15.2/dist/katex.min.css) and load it as an asset from your server directly.
You can find more information on [KaTeX's website](https://katex.org/docs/browser.html).

## Contributions and bug reports
Feel free to repost any bugs or even make feature request in [issues on official repository](https://github.com/yagarea/jektex/issues).
I am opened for pull requests as well.
