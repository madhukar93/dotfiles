export type Session = { id: string; when: string; title: string; recap: string }
export type Proposal = { id: string; name: string; recap: string }

declare module 'claude-code' {
  interface PluginState {
    'sessions': {
      sessions: Shaped<Session[]>
      query: Shaped<string>
      proposals: Shaped<Proposal[]>
      status: Shaped<string>
      selected: Shaped<string>
      ring: Shaped<string>
    }
  }
}
