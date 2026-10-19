# Vercel deployments from source

Generated `build/` directories are local artifacts and are not tracked by Git.
Vercel builds Flutter on each deployment using `scripts/build-vercel.sh` and
serves the resulting `build/web` directory. The FTP workflow continues to build
and upload its own output.

Configure each Vercel project's Root Directory to select the application:

| Application | Root Directory |
| --- | --- |
| Learning app | Repository root (`.`) |
| Admin dashboard | `apps/admin_web` |

Do not use `build/web` or `apps/admin_web/build/web` as the Root Directory.
For the admin project, enable **Include source files outside of the Root Directory
in the Build Step**: it needs the shared build script and the existing
`packages/bitclass_notifications` dependency.

The checked-in `vercel.json` files specify the build command and output directory.
The script installs Flutter 3.44.8, matching `.github/workflows/deploy.yml`, then
fetches dependencies and builds in production mode.

The script uses the same public Supabase URL and anonymous key defaults as FTP.
Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in Vercel to override them for a
different project. These values are embedded in the public browser bundle; never
use a service-role or secret key.

After the first push, check the Vercel deployment logs for a successful Flutter
build and verify sign-in and direct page links on the deployed site.
