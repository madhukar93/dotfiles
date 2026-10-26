# Terminal workspace

How terminals, panes and coding agents are organised on these machines, across tmux and herdr
(a terminal multiplexer built for coding agents).

## Language

**Workspace**:
A named group of tabs for one project, usually one git repository. tmux calls this a session.
_Avoid_: session (in herdr that word means a whole server), project

**Herdr session**:
One running herdr server and everything in it: its workspaces, tabs and panes. Named with `herdr --session`.
_Avoid_: session on its own, server

**Tab**:
One task inside a workspace, holding one or more panes. tmux calls this a window.
_Avoid_: window

**Pane**:
One terminal inside a tab.
_Avoid_: split, terminal

**Prefix**:
The key pressed first to tell the multiplexer that the next key is a command for it, not for the program in the pane.
_Avoid_: leader

**Agent work**:
Any workspace where a coding agent runs, together with that project's servers, tests and shells. It lives in herdr; work not tied to an agent (ssh sessions, k9s, long jobs outside a repo) lives in tmux.
_Avoid_: AI work, agent stuff
