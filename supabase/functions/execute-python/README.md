# Execute Python Relay

This authenticated Supabase Edge Function validates Python playground requests
and relays them to the separate BitClass code-runner service. It never executes
student code and never sends Supabase credentials to the runner.

Configure the runner endpoint and a randomly generated secret of at least 32
characters:

```powershell
supabase secrets set CODE_RUNNER_URL=https://runner.example.com
supabase secrets set CODE_RUNNER_SHARED_SECRET=replace-with-a-random-secret
```

Deploy with JWT verification enabled:

```powershell
supabase functions deploy execute-python
```

The endpoint accepts at most 20 KB of Python source and 8 KB of standard input.
The runner is responsible for centralized rate limits and sandbox enforcement.

