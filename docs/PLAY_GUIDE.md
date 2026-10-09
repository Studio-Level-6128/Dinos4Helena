# How to play Dinos4Helena

## Start an adventure

Choose **Free Game** on the landing page, then select one of seven dinosaurs. Each species has different speed, strength, health and jumping ability. Enter a six-digit world seed to revisit the same valley, or select **New Random Seed**.

## Play together

The default multiplayer server is `wss://92.205.18.100:8765/` with TLS and self-signed certificates enabled. To use another server, open **Configuration** at the bottom-left of the start screen, enter its IP address or host name and port, choose the TLS options, and save. **Test Server Connection** checks the current fields without saving them; it briefly joins the game to verify the connection. On a local network, use the host computer's LAN address (for example `192.168.1.50`). Allowing a self-signed certificate encrypts the connection but does not verify the server's identity. The app remembers saved settings. Then choose **Multiplayer** to browse ongoing sessions. Join one and choose your dinosaur, name, and color, or create a session by selecting a map theme as well. The name and color are saved locally when you connect and restored next time. Each session supports up to ten players and has its own grassland, desert, winter, or volcano map. Wildlife uses the same AI behavior as in free play. The in-game player list shows each name in its color; a matching colored token floats above each human-controlled dinosaur.

The server runs separately from the game. Whoever hosts it can follow the [server setup guide](../server/README.md). `127.0.0.1` works only when the game and server run on the same device.

## Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Move and steer | Drag the right-hand wheel; every direction combines forward/backward movement with steering | `WASD` or arrow keys |
| Jump | **Jump** | `Space` |
| Run | Hold **Run** while moving | `Shift` |
| Duck | Hold **Duck** | `C` or `Ctrl` |
| Attack | **Attack** — usable while walking, running or jumping | `F` |
| Eat | Hold **Eat** near food | `E` |
| Scream | **Scream** | `R` |

The camera follows above and behind your dinosaur. The top-right button returns to the main menu.

## Survive

Health and energy appear at the top left. All actions consume energy; running, jumping and attacking consume the most. If energy reaches zero, health begins falling.

- Herbivores recover energy slowly by eating nearby plants.
- Carnivores recover energy quickly from meat left by defeated dinosaurs.
- Glowing purple plants with bright red pods are poisonous. Eating one makes health fall continuously and displays a purple warning.
- Red tokens restore health and cure poisoning immediately.
- Blue speed tokens and orange strength tokens double that attribute temporarily.

At zero health, the dinosaur dies and the game ends.

## Wildlife

Herbivores move in packs, flee hunters and fight back when attacked. Packs protect members of their own species, including a matching player. Their moving formation sometimes leaves one animal trailing behind.

Carnivores hunt alone. Healthy hunters strongly prefer babies and accept riskier baby attacks, although a powerful nearby parent or pack can still deter them. They continue moving through pursuit attacks, avoid hopeless adult fights, feed after a kill, and retreat once their health falls below half. Dinosaurs do not attack their own species.

## Breed a baby

Look for small eggs sitting in nests. Walk directly over an egg and hold **Duck** for four uninterrupted seconds. The egg hatches into a smaller dinosaur of your species.

The baby follows beside you and has its own health, but no energy meter. It is slower than an adult and predators can kill it, so keep it close and protect it.

## Explore the valley

The world contains forest and grassland regions, rivers, lakes, hills, jumpable ledges, trees, rocks, plants and fallen logs. Solid scenery cannot be walked through, and invisible walls prevent falls from the map edge.

The minimap reveals nearby terrain as you explore. Living predators appear as red dots and herbivores as green dots wherever their current position has been explored. A whole herbivore pack uses a single green marker to keep the map readable. Red-and-cream feast symbols show meat left by defeated dinosaurs. The sun, moving clouds, ambient wildlife, tokens, eggs and dinosaurs all form part of the seeded world.

## Beyond the Frozen Pass

Open **Quests** and select **Beyond the Frozen Pass** for six winter missions.
The first mission is available immediately; each completion unlocks the next.
Titles, objectives, hints, and spoken introductions follow the selected English,
German, or French language.

1. **Tracks in the Snow:** Follow footprints with toes pointing forward.
   Backward-curving branches return you to your last checkpoint.
2. **Whiteout:** Wait beneath rocky shelters during strong wind. Shelters
   restore warmth; calm spells give you time to reach the next one.
3. **The Singing Lake:** Dark blue islands are safe. Pale ice starts creaking
   before breaking, so keep moving until you reach the next island.
4. **Let Sleeping Giants Lie:** Walk on the white snow paths. Running,
   noisy ice, attacking, or screaming can disturb a nearby giant. Stop when
   it stirs. Hurting a giant fails the mission.
5. **The Snowplug:** Stand behind each boulder and walk forward to push it
   along its blue channel to the highlighted marker. Three ready channels
   reopen the snow-blocked tunnel.
6. **The Last Avalanche:** Blue slopes are clear, amber warns of a coming
   slide, and red means take cover. Reach three rocky checkpoints, then
   continue into the green valley.

Cold, broken ice, noise, and avalanches return you to your latest checkpoint
without erasing progress in the mission. Dying ends the attempt. Every warning
also appears as text, so audio is optional.

## Heart of the Volcano

The fourth quest uses a different dinosaur in each of its six lava-world missions.
Titles, objectives, hints, and narration follow your English, German, or French
language choice. Completing a mission unlocks the next and saves your progress.

1. **Echoes of Warning — Parasaurolophus:** A dot means a short roar and a line
   means a long roar. Tap **Scream** (`R`) for short; hold for at least one second
   and release for long. Answer three patterns. **Replay Call** repeats the
   sounds and visible words; mistakes only restart the current pattern.
2. **Leap of Fire — Velociraptor:** Jump onto each moving basalt platform, ride
   it upward, then jump to the next ledge. You must land on both the platform
   and ledge for each checkpoint. Walking plus Jump works; Run is optional.
3. **The Giant’s Balance — Apatosaurus:** Walk up the ramp to the three glowing
   points. Stay at each point until the slab levels out and its hold meter fills.
   Keep away from the edges, then cross down the far ramp.
4. **Break the Black Wall — Triceratops:** Face a glowing crack squarely, hold
   **Run**, and press **Attack** while approaching it. Open all three wall
   sections, then pass through. Walking attacks and glancing charges do not
   break the wall.
5. **Return to Sender — Stegosaurus:** The challenge starts when you enter the
   landing circle. Press **Attack** when it turns green to deflect the incoming
   stone. The normal attack animation has a short wind-up, so press early in
   the green window. Return five stones into the barriers. Misses allow a retry.
6. **Ashfang, Lord of the Crater — Spinosaurus:** His three health-bar segments
   represent three phases. Move away from marked charge lines, stay outside
   the tail-sweep circle, then approach and **Attack** during green recovery
   windows. The last phase alternates both attacks and adds lava patches:
   amber warns, red burns. Defeating a phase restores health and energy.
   If a boss attack or lava overwhelms you, retry the current phase while
   keeping earlier phases won. When Ashfang retreats, cross into the green
   valley to finish the quest.

Falls and balance mistakes return you to your last checkpoint. Ordinary player
death ends the attempt. No mission requires sound to understand its cues.
