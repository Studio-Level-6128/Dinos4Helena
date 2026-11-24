"""Build the field guide with Python 3 and Pandoc; no runtime dependencies."""
from pathlib import Path
from string import Template
import re
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = ROOT / 'docs'
GUIDES = {
    'docs/INSTALL.md': ('install', 'Install the game', 'Set up Android or play on a Linux computer.'),
    'docs/PLAY_GUIDE.md': ('play', 'Player guide', 'Learn the controls, find food, and protect your young.'),
    'server/README.md': ('multiplayer', 'Multiplayer hosting', 'Set up a server so friends can share a valley.'),
    'docs/DEVELOPMENT.md': ('development', 'Development', 'Run the project and explore how the game works.'),
    'docs/QUEST_AUTHORING.md': ('quests', 'Quest writing', 'Build a campaign with its own missions and objectives.'),
    'translations/README.md': ('translations', 'Translations', 'Help dinosaurs speak another language.'),
}
layout = Template((HERE / 'layout.html').read_text())


def page(file, title, content, prefix=''):
    file.write_text(layout.substitute(title=title, content=content, prefix=prefix))


def build():
    # docs also holds the source Markdown and screenshots; never clean this tree.
    (OUT / 'guides').mkdir(exist_ok=True)
    shutil.copy(HERE / 'style.css', OUT)

    cards = []
    for source, (slug, title, summary) in GUIDES.items():
        body = subprocess.check_output(['pandoc', '--from=markdown', '--to=html5',
                                        '--no-highlight', ROOT / source], text=True)

        def guide_link(match):
            target = ((ROOT / source).parent / match[1]).resolve().relative_to(ROOT)
            return f'href="{GUIDES[target.as_posix()][0]}.html{match[2] or ""}"'

        body = re.sub(r'href="([^":#?]+\.md)(#[^"]*)?"', guide_link, body)
        page(OUT / 'guides' / f'{slug}.html', title,
             '<article><a href="../index.html#guides">← All field guides</a>' + body + '</article>', '../')
        cards.append(f'<a class="card" href="guides/{slug}.html"><strong>{title}</strong>{summary}</a>')
    home = Template((HERE / 'home.html').read_text()).substitute(cards='\n'.join(cards))
    page(OUT / 'index.html', 'Field Guide', home)


if __name__ == '__main__':
    build()