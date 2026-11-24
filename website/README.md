# Field guide website

From the repository root, with Python 3 and Pandoc installed:

```sh
python3 website/build.py
python3 -m http.server 8000 --directory build/pages
```

Open `http://localhost:8000/`. Edit the original Markdown guides to update their subpages; the build generates the HTML and fixes links between guides. The homepage and shared layout live beside the build script. Screenshots come from `docs/images/`.

To publish, choose **Settings → Pages → Build and deployment → Source → GitHub Actions** in the repository. Push the changes to `main` or run **Publish field guide** from the Actions tab. Only the generated site is uploaded.