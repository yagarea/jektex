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

## Usage

### Notation
**Inline formula**  
Put formula between two pairs of `$` inside of paragraph.

```latex
Lorem ipsum dolor sit amet, consectetur $$e^{i\theta}=\cos(\theta)+i\sin(\theta)$$
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
```

**Display formula**  
Put formula between two pairs of `$` and surround it between two empty lines.
```latex
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor 
incididunt ut labore et dolore magna aliqua.

$$ i\hbar\frac{\partial}{\partial t} \Psi(\mathbf{r},t) = \left [ \frac{-\hbar^2}{2\mu}\nabla^2 + V(\mathbf{r},t)\right ] \Psi(\mathbf{r},t) $$

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
ea commodo consequat.
```

_Why Jektex does not use conventional single `$` for inline formulas and double `$$` for
display mode?  
Unfortunately this is how [kramdown](https://kramdown.gettalong.org/) 
(Jekyll's markdown parser) works and it would probably do be easier to write custom 
markdown parser than hacking kramdown to behave differently._

### Macros
You can define global macros in your `_config.yml` file:

```yaml
# Jektex macros
jektex-macros:
    - ["\\Q", "\\mathbb{Q}"]
    - ["\\C", "\\mathbb{C}"]
```

### Clearing cache
To clear cached expressions you have to delete `.jektex-cache` directory in your 

## Installation

### Using bundler
Add `jektex` to your `Gemfile` like this:

```yaml
group :jekyll_plugins do
    gem "jektex"
end
```

and run `bundle install`

### Without bundler
Just run `gem install jektex` and add jektex to your plugin list in your `_config.yml` 
file:
```yaml
plugins:
    - jektex
```

### Style sheets
Do not forget to add `katex.min.css` to you html head:
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.15.2/dist/katex.min.css" integrity="sha384-MlJdn/WNKDGXveldHDdyRP1R4CTHr3FeuDNfhsLPYrq2t0UBkUdK2jyTnXPEK1NQ" crossorigin="anonymous">
```
It is much better practice to download **css** file and loaded as an asset from your server directly.

