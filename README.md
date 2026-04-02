# vscodium-langservers-extracted

Extract HTML/CSS/JSON/ESLint language servers from official builds of
[VSCodium](https://github.com/VSCodium/vscodium).

The goal is to provide a drop-in replacement for
[`vscode-langservers-extracted`](https://github.com/hrsh7th/vscode-langservers-extracted).

A secondary goal is to minimize dependence on any single maintainer.  Anyone can
generate updated language servers from a current VSCodium release using a small,
portable shell script with minimal dependencies.

# Provided Language Servers

- CSS: `vscode-css-language-server`
- ESLint: `vscode-eslint-language-server`
- HTML: `vscode-html-language-server`
- JSON: `vscode-json-language-server`

`vscode-markdown-language-server` is listed as "soon" in the
`vscode-langservers-extracted` project.  There isn't a configuration for using
it in [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig).  All I have
done is verify that it starts up correctly when provided a `--stdio` argument.

# Usage

## NPM

`vscode-html-language-server` depends on the Typescript compiler for editing
Javascript code inline in HTML.  `vscodium-langservers-extracted` thus declares
`typescript` in its `peerDependencies` so that you can control the version of
the Typescript compiler used by the language server.

The easiest way to get up and running is to install globally.

```
npm install -g typescript
npm install -g vscodium-langservers-extracted
```

If your editor provides a way of running "inside" a project environment managed
by `npm`, or another package manager, you can ensure that the language servers
use the same version of the Typescript compiler that your project uses.

```
# Assuming your project already has Typescript installed
npm install --save-dev vscodium-langservers-extracted
# vscode-html-language-server will use your installed Typescript via
# peerDependencies
```

For a terminal-based editor like Neovim or (for some) emacs, you can create a
`package.json` script that runs your editor, and the project-local language
servers will be on your path.

## Local Extraction

If you clone the Github repo, you can use the `extract-langservers.sh` script to
extract the language servers, locally, and use them however you want.

```
sh ./extract-langservers.sh -o output_dir -l
```

Extracts language servers from the latest versions of
[VSCodium](https://github.com/VSCodium/vscodium) and the [ESLint
extension](https://open-vsx.org/extension/dbaeumer/vscode-eslint).  Places the
language servers, along with `vscode-langservers-extracted`-compatible launch
shims, in `output_directory`. One possible invocation that may work well for you
is

```
sh ./extract-langservers.sh -o ~/.local/bin -l
```

placing the language servers among your user binaries.

If the current versions of the language servers are not working with your
editor, you can specify the locations of prior versions with

```
sh ./extract-langservers.sh -o output_dir -c vscodium_archive_url -e eslint_extension_archive_url
```

Provide full URLs to the installation archives for VSCodium and for the [ESLint
VS Code extension on Open
VSX](https://open-vsx.org/extension/dbaeumer/vscode-eslint).  Use the location
of a **Linux x64 .tar.gz** archive for VSCodium.  The only code extracted from
the archive is Javascript. It will work on any platform supported by Node.
Archives for other platforms may place the bundled language servers in different
locations and cause extraction errors.

With any of these invocations, you can optionally check the integrity of the
VSCodium archive with the `-i` flag.

```
sh ./extract-langservers.sh -i -o output_dir -c vscodium_archive_url -e eslint_extension_archive_url
```

The integrity check requires that the `openssl` command line tool be available.

Open VSX does not currently export archive integrity hashes for its extension
archives.

# Dependencies

`extract-langservers.sh` depends on `curl`, `gzip`, `tar` (GNU and BSD tar have
been tested and found to work), `jq` (only if the `-l` option is specified),
`openssl` (only if the `-i` option is specified), and `unzip`.  `install` is
also used, and turns out not to be in the POSIX specification, but nearly every
Unix environment has `install` available.  Of these, `jq` and `unzip` are the
most likely to be missing on your system.

`node` remains a requirement for using the language servers.

# Why?

For years, I have been reliant on the
[`vscode-langservers-extracted`](https://github.com/hrsh7th/vscode-langservers-extracted)
project for access to the Web language servers bundled into VS Code _outside_ of
VS Code, specifically in [Neovim](https://neovim.io).

`vscode-langservers-extracted` hasn't seen any updates since mid-2024, and the
project was left in a state in which the ESLint language server was
[nonfunctional](https://github.com/neovim/nvim-lspconfig/issues/3146), at least
on Neovim.  I am not complaining!  I am indebted to the maintainers of
`vscode-langservers-extracted` for hundreds of hours of productivity in Web
languages thanks to their work. Nonetheless, I wanted to get ESLint working in
Neovim again.  I started poking at the project to see if I could produce updated
builds.  I had some success, but, in my local build, the HTML language server
crashed on startup for reasons I was not excited about debugging.  That got me
brainstorming about alternative approaches to solving the problem of making VS
Code language servers available outside of VS Code.

## An Alternative Approach:  VS Codium Official Builds

`vscode-langservers-extracted` works by pulling the latest source for VS Code
and the latest source for the VS Code ESLint extension, and compiling them from
scratch.  I can't be certain, but I think this approach was chosen because
official build archives of VS Code from Microsoft come with a restrictive
license that would make extracting the language servers and using them with
other editors a dubious proposition.  Building from Microsoft's MIT-licensed
source doesn't incur the restrictions that come with using an official Microsoft
build of VS Code.

Thankfully, these days, we have the excellent
[VSCodium](https://github.com/VSCodium/vscodium) project.  VSCodium provides
prebuilt packages of _only_ the open source portions of VS Code, in step with VS
Code, itself, under the same, permissive, MIT license as the original source
code.  Extracting the language servers from the VSCodium releases allows us to
use them with other editors without fear of repercussion.

### The HTML language server and inline Javascript

The HTML language server has a hard, external dependency on the Typescript
compiler.  Depending on Typescript allows the HTML language server to provide
the full Javascript editing experience for inline scripts embedded in HTML.  The
downside is that starting the HTML language server requires a large, complex,
dependency for a use case that many develops rarely encounter.  This project
takes a compromise approach to satisfying the dependency.

#### If you install using `extract-langservers.sh`

VS Code, and thus, VSCodium, bundle some version of the Typescript compiler for
use by any of the language servers bundled into VSCodium.
`extract-langservers.sh` copies _just_ enough of the bundled Typescript compiler
(`typescript.js` and `package.json`) to allow the HTML language server to start.
It does _not_ copy any of the type definitions that are distributed with the
Typescript compiler, to keep the number of files that need to be installed to an
absolute minimum.  Without the type definitions, the experience of editing
inline Javascript in HTML is degraded.  In most projects, Javascript inline in
HTML is kept to a minimum, making the tradeoff worthwhile.

#### If you install the NPM package

The NPM package does not include any of the Typescript compiler code bundled
into VSCodium.  It instead places `typescript` in `peerDependencies`.  Thus,
you will need to install `typescript` to get the HTML language server to start.

## Advantages of Extracting from VSCodium

- No reliance on individual maintainers to provide updated builds of the VS Code
  language servers.  Any VSCodium release can provide language servers at any
  desired version.
- No need to clone a very large repository.
- No need to ensure build dependencies are met.  The extraction process uses a
  simple shell script with minimal dependencies.
- Language server availability is not tied to NPM.  The language servers can be
  installed wherever needed.

## Drawbacks of Extracting from VSCodium

- The language server code is minified, making it difficult to debug issues.
