# Execute Code Relay

This authenticated Supabase Edge Function validates Python and C Code Lab
requests, then relays them to the separate BitClass code-runner service. It
does not execute student code or expose Supabase credentials to the runner.

Configure the runner endpoint and a randomly generated secret of at least 32
characters:

```powershell
supabase secrets set CODE_RUNNER_URL=https://runner.example.com
supabase secrets set CODE_RUNNER_SHARED_SECRET=replace-with-a-random-secret
```

Deploy with JWT verification enabled:

```powershell
supabase functions deploy execute-code
```

Requests must use the `python` or `c` language identifier and contain no more
than 20 KB of source and 8 KB of standard input. The runner is responsible for
centralized rate limits, compilation, and sandbox enforcement.
