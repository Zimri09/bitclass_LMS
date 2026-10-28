# BitClass Code Runner

This service runs one Python, C, or Java file per disposable gVisor container. It is
intended for a dedicated Linux host and must not share a machine with Supabase,
databases, CI workers, or other sensitive services.

## Security boundary

Each execution uses a fixed command and enforces:

- gVisor's `runsc` OCI runtime
- no container network
- non-root user and all Linux capabilities dropped
- read-only root filesystem with no host directory mounted
- a bounded memory limit (1 GB by default), 0.5 CPU, 32 processes for
  Python or 64 for GCC/Java, 256 open files, and a 5 second limit for Python/C
  or 20 seconds for Java (including compilation)
- 32 KB each for stdout and stderr
- no image pulls during requests
- immediate container cleanup

The service sends bounded source and program input to fixed, language-specific
bootstraps over standard input. C source is compiled as C17 with a fixed GCC
command before its temporary binary is executed. It does not accept shell
commands, filenames, compiler arguments, packages, environment variables, or
mounts from the caller, and it logs neither source code nor program input.

## Host setup

1. Provision a dedicated Linux VM.
2. Install Docker Engine and gVisor, then configure Docker's `runsc` runtime.
3. Verify isolation with `docker run --rm --runtime=runsc hello-world`.
4. Pull approved Python and GCC images as an administrator.
5. Record both immutable digests with
   `docker image inspect --format '{{index .RepoDigests 0}}' IMAGE_NAME`.
6. Set the variables shown in `.env.example`. Use the same random shared secret
   for `CODE_RUNNER_SHARED_SECRET` in Supabase.
   Size `RUNNER_MAX_CONCURRENT` so its combined memory limits leave capacity for
   the host; the example uses one 1 GB job on a 2 GB VM.
7. Start the service with `dart run bin/server.dart` from this directory.
8. Place an HTTPS reverse proxy in front of the loopback listener and allow
   requests only from the Supabase relay where infrastructure permits. When
   using Caddy, explicitly proxy both execution routes:

   ```caddyfile
   runner.example.com {
     @runner path /healthz /v1/execute/python /v1/execute/c /v1/execute/java
     handle @runner {
       reverse_proxy 127.0.0.1:8080
     }
     respond 404
   }
   ```

The service intentionally refuses to start on Windows or macOS. Membership in
the Docker group is effectively privileged host access, which is why this must
run on an otherwise disposable, dedicated VM.

## Health check

`GET /healthz` returns `{"status":"ok"}` without running a container. Program
execution requires `POST /v1/execute/python` or `POST /v1/execute/c` with the
private `X-Runner-Token` header. Never expose that token to Flutter clients.

## Enabling Java

Java is optional so an existing Python/C installation can still start without a
JDK image. Java requests return a configuration error until it is configured.

1. Pull an approved Linux Java 21 JDK image (for example the Ubuntu-based
   Eclipse Temurin 21 JDK image, including `sh`, `dd`, and `cat`). Record its
   immutable repository digest as above and set `JAVA_RUNNER_IMAGE` on the host.
2. Install this runner version and restart it. Startup verifies the pinned image
   is installed. Add `/v1/execute/java` to the reverse proxy routes.
3. Deploy the updated `execute-code` relay, then the Flutter app.
4. Verify an authenticated Java run prints `0` through `4`, a Scanner program
   reads supplied input, invalid source produces a compile error, and an infinite
   loop times out. Recheck Python and C before publishing to students.

Java uses a fixed `javac --release 21` command and runs `Main` from a temporary
classpath. Use `public class Main` and `public static void main(String[] args)`
without a package declaration. Multiple helper classes in that file are allowed;
external libraries, Maven/Gradle, and network downloads are not supported.
Java compilation and execution share a twenty-second budget and container
isolation. The JVM heap is capped at 128 MB within the existing container memory
limit; temporary files are limited to 32 MB. No schema migration is needed.
