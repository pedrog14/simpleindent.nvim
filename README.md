# simpleindent.nvim
Simple indentation guides, heavily inspired by [mini.indentscope](https://github.com/nvim-mini/mini.indentscope) and [snacks.indent](https://github.com/folke/snacks.nvim/blob/main/docs/indent.md)

<img width="1920" height="1080" alt="Indent guides (sw=2)" src="https://github.com/user-attachments/assets/4da80472-8c98-4cb2-99bb-1976d52f7b94" />


# Requirements
- Neovim >= 0.10.0

# Installation

### [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  "pedrog14/simpleindent.nvim",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {},
}
```

### [`vim-plug`](https://github.com/junegunn/vim-plug):

```vim
Plug 'pedrog14/simpleindent.nvim'
```

### Built-in plugin manager ([`vim.pack`](https://neovim.io/doc/user/pack.html#vim.pack)):

```lua
vim.pack.add({ { src = "https://github.com/pedrog14/simpleindent.nvim" } })
```

# Configuration

Default settings:
```lua
{
  filter = {
    filetype = {
      "lspinfo",
      "packer",
      "checkhealth",
      "help",
      "man",
      "gitcommit",
      "dashboard",
      "text",
      "",
    },
    buftype = { "terminal", "quickfix", "nofile", "prompt" },
  },
  symbol = "▏",
}
```

You can enable your plugin and/or modify your settings by calling `require("simpleindent").setup` with the proper argument table (only needed **if you want to modify default settings**), as presented above. 
