# Field guide website

From the repository root, with Python 3 and Pandoc installed:

```sh
python3 website/build.py
python3 -m http.server 8000 --directory docs
```

Open `http://localhost:8000/`. Edit the original Markdown guides to update their subpages; the build generates the HTML and fixes links between guides. The homepage and shared layout live beside the build script. Screenshots come from `docs/images/`.

To publish, commit the generated HTML and CSS in `docs/` alongside any source edits and push to `main`. In **Settings → Pages**, choose **Deploy from a branch**, select **main** and **/docs**, then **Save**. The `website/` folder contains build tools and templates only; it is not a publishing source. Rebuild and commit the generated files whenever guides, templates, or styles change.