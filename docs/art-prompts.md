# Art prompts (ChatGPT drafts)

ChatGPT 이미지 생성에 넘길 프롬프트 모음. **초안용**이다 — 나온 그림은 방향
잡기와 실루엣 참고로 쓰고, 실제 게임 에셋은 네이티브 해상도로 다시 찍는다.

쓰는 법:

1. 새 대화를 열고 **[0. 스타일 바이블]** 을 통째로 붙여 넣는다. 그림은 아직
   요청하지 않는다.
2. 그 다음 메시지부터 **[1]~[5]** 중 하나씩 붙여 넣는다. 한 번에 한 장.
3. 스타일이 흐트러지면 "Re-read the style bible and redo it" 한 줄로 되돌린다.
4. 마음에 든 결과는 `source/assets/art/drafts/` 에 둔다 (게임이 읽지 않는
   위치 — 정식 에셋과 섞지 말 것).

영어로 쓴 이유: 이미지 모델이 영어 지시를 더 정확히 따른다. 이름은 한국어를
괄호로 같이 줬다.

---

## 0. 스타일 바이블 (첫 메시지로 한 번만)

```
You are helping me draft concept art for a pixel-art deck-building roguelike.
Read this whole brief and reply only "understood" — I will ask for images one
at a time afterwards. Apply every rule below to every image unless I say
otherwise.

THE GAME
A god's hourglass wore out and broke, and time spilled into the ordinary
mortal world below. The Warden — a small figure the god made in a hurry out
of the last time that did not leak — walks down to gather it back. The things
it fights are the Askew (어긋난 것들): not monsters but ordinary moments that
broke under the weight of spilled time — a door that keeps opening, an
evening that keeps happening, a word someone swallowed. They do not threaten
or attack out of malice. They simply continue. The Warden interrupts them.

TONE
Cold and sorrowful, with something quietly wrong underneath. "Sad
wrongness." Things that should not be, and are not monstrous about it.
- Nothing roars. No fangs, claws, glowing red eyes, snarling faces, gore,
  tentacles or demon imagery. Ever.
- No villains, no heroic poses, no action lines, no dramatic lighting.
- Understated, still, almost domestic. The world is an ordinary low-fantasy
  village/town: kitchens, doorways, roads, lamps, beds, clocks, tables.
- The wrongness is in small things: a shape repeated twice, a shadow pointing
  the wrong way, a thing frozen mid-motion, something worn far older than it
  should be.

PIXEL ART RULES
- True pixel art on a clean square grid: every pixel the same size, hard
  edges, no anti-aliasing, no gradients, no soft shading, no blur, no
  painterly texture, no dithering noise, no outer glow.
- Draw at a low native resolution and show it scaled up by a whole number
  (e.g. 6x or 8x) with nearest-neighbour scaling, so individual pixels are
  clearly visible squares. Tell me the native size you drew at.
- The whole game is pixel art — characters, enemies, backgrounds, icons.
  Everything in the game world shares ONE pixel size: in game, one art
  pixel = 6 x 6 screen pixels on a 1920 x 1080 screen (so a full-screen
  background is 320 x 180 native). Never mix pixel sizes inside an image,
  never draw a "high-res" element next to chunky pixels, and never rotate or
  freely scale pixel shapes (that creates uneven, mixed-size pixels).
- Flat, simple, readable silhouettes. Detail that would not survive at 24
  pixels tall gets cut: no gearwork, rune borders, filigree, layered drapery,
  fine mechanical parts.
- One subject per image, centred, full body visible, on a flat solid
  background of #15151B. No scenery behind characters unless I ask for a
  background. No text, no UI, no frame, no signature.

PALETTE (low chroma, high contrast)
Use only these colours plus at most two darker/lighter steps of each:
  #15151B  near-black (background, ink)
  #0D0D12  deepest shadow
  #1E1E26  panel dark
  #2A2A36  raised dark
  #8A8276  dim grey-brown (worn things, stone, wood)
  #DED8CA  bone (cloth, pale surfaces)
  #E6E1D6  bone light
  #F2EEE6  white — reserved: this is the colour of time itself
  #D9A441  gold — rare accent, at most one small spot per image
  #A34B4B  dull blood red — rare, only where I ask
  #6F8F5F  muted green — rare, only where I ask
Overall the image must read as desaturated. The clean white (#F2EEE6) should
be the brightest, purest thing in the picture — it is time, the thing being
taken back.

THE WARDEN (protagonist, for reference — keep it consistent whenever it
appears)
- 24 x 40 pixels native. Small, slight, ambiguous, not human-proportioned
  quite right — made quickly by a god not practised at bodies.
- A long near-black cloak with a ragged hem, a mass of near-black hair, and a
  pale bone-white featureless mask that is a clock face: a single gold hand
  points to how much life it has left. No mouth, no eyes drawn on the mask.
- A pale white drape across the shoulders, one pale hand visible.
- Gold appears in exactly two places on it (the clock hand and one tiny
  detail), nowhere else.
- Expression: none. Posture: still, patient, slightly too upright.

ACT ONE ASKEW (the enemies I'll ask for first)
In act one you can still tell what the moment was. Each Askew is an
everyday thing or moment given a body — recognisable at a glance, with one
thing wrong about it. Not a person in a costume, not a cute mascot, not a
monster. Think of a still life that has started, very slightly, to stand up.
Enemy sprites are 32 x 40 pixels native for normal Askew, up to 48 x 48 for
elites and 64 x 64 for bosses.
```

---

## 1. Warden

```
Draw the Warden exactly as described in the style bible: 24 x 40 native,
shown at 8x, standing, three-quarter view facing right, still. Then, in a
second image, draw only the clock-face mask at 10 x 10 pixels native in four
states side by side — the gold hand at full, most, half, and nearly out.
```

---

## 2. 1막 Askew — 한 장에 하나씩

아래 줄을 하나씩 이 틀에 넣어 보낸다:

```
Draw the act-one Askew "<NAME>" at <SIZE> native, shown at 8x, following the
style bible. <DESCRIPTION> Keep it still and quiet; it is not attacking.
```

`<DESCRIPTION>` 은 아래 표의 영어 문장을 그대로 넣는다. 설명은 이름과
전투 기믹에서 뽑은 **제안**이다 — 이상하면 고쳐서 쓴다.

### 단독 (32 x 40)

| id | NAME | DESCRIPTION |
|---|---|---|
| squabble | Squabble (실랑이) | Two small tangled shapes like a knot of two coats tugging the same sleeve in opposite directions, frozen mid-pull. |
| doorsill | The Doorsill (문턱) | A worn wooden doorway threshold standing upright on its own, a lit evening doorway seen through it that grows warmer — a hint of gold light at the bottom edge. |
| draught | The Draught (외풍) | A thin pale curtain hanging from nothing, blown sideways by a wind that is not there; its folds are bone-white streaks. |
| swallowed_word | The Swallowed Word (삼킨 말) | A small figure-like shape made of a throat and a closed mouth outline, with a white speech mark stuck inside it, unable to come out. |
| tossing | Tossing (뒤척임) | A rumpled blanket shaped like someone turning over in bed, but empty, permanently mid-turn. |

### 무리 (32 x 40 각각)

| id | NAME | DESCRIPTION |
|---|---|---|
| breakfast | Breakfast (아침밥) | A small table setting for one — bowl, spoon, a cup still steaming white — standing on thin table legs. Morning. |
| nap | The Nap (낮잠) | A folded cushion with a dent where a head lay, slowly sinking, a sliver of afternoon light across it. |
| sundown | Sundown (저녁놀) | A window frame holding a low sun that never finishes setting, the only warm gold in the image. |
| supper | The Late Supper (밤참) | A covered plate left out on a stool for someone who has not come home, a single candle stub beside it. |
| chorister | A Voice (목소리) | A narrow, hooded hollow shape like an empty choir robe, its open mouth a small white oval. Draw it so three identical copies could stand side by side. |
| domino | The Domino (도미노) | A tall upright domino tile, slightly tilted forward, as if it is always about to fall onto the next. Bone-coloured pips. |
| runner | The Runner (주자) | A pair of worn shoes and trouser hems mid-stride with no body above the knees, a relay baton in white. |
| hourglass_upper | The Upper Bulb (윗칸) | The top half of a cracked glass hourglass, white sand running down out of the bottom into nothing. |
| hourglass_lower | The Lower Bulb (아랫칸) | The bottom half of a cracked glass hourglass, filling with white sand from above that comes from nowhere. |
| shelter_front | The One in Front (앞에 선 것) | A broad, plain shape like a parent's coat spread wide with arms out, standing protectively. |
| shelter_behind | The One Behind (뒤에 숨은 것) | A small shape like a child's coat peeking out from behind something, only half of it visible. |

### 정예 (48 x 48)

| id | NAME | DESCRIPTION |
|---|---|---|
| murphys_law | Murphy's Law (머피의 법칙) | A piece of buttered bread forever falling butter-side down, frozen just above the floor, with small things around it tipping over in sympathy. |
| prop | The Prop (버팀목) | A heavy wooden beam wedged at an angle, holding up a sagging ceiling corner that is not there. Patient, enduring. |
| seesaw_near | This End (이쪽 끝) | The near end of a child's playground seesaw, pressed down. Draw so it pairs with "That End". |
| seesaw_far | That End (저쪽 끝) | The far end of the same seesaw, raised up in the air. |
| throng | The Throng (북새통) | A crowd of many overlapping coat and hat silhouettes pressed into one lumpy mass, white hours spilling from its pockets. |
| second_hand | The Second Hand (초침) | A thin, fast clock hand standing alone, the lightest of three. Pairs with Minute Hand and Hour Hand. |
| minute_hand | The Minute Hand (분침) | A longer clock hand standing alone, middle weight. |
| hour_hand | The Hour Hand (시침) | A short, heavy clock hand standing alone, the slowest and heaviest of three. |

### 보스 (64 x 64)

| id | NAME | DESCRIPTION |
|---|---|---|
| echo | The Echo (메아리) | A hollow empty room's corner, its shape repeated inward three times like an echo, each repetition fainter. Whatever is done to it comes back. |
| sun_dragger | The One Who Drags the Sun (해를 끄는 것) | A long, stooped, rope-thin figure pulling a pale sun across the ground behind it on a cord, so the day lasts longer than it should. The sun is the brightest thing in the image. |

### 아직 인카운터에 안 들어간 것 (나중에)

| id | NAME | DESCRIPTION |
|---|---|---|
| bottomless | The Bottomless (밑 빠진 것) | A clay jar with no bottom, white hours pouring straight through it onto the floor. |
| yesterday | What Was Yesterday (어제였던 것) | A calendar page torn off and standing upright, its date faded beyond reading, curling at the edges. |
| sunken | The Sunken (가라앉은 것) | A chair half sunk into the floor as if the floor were water, heavy and slow. |

---

## 3. 유물 아이콘

```
Draw a relic icon for "<NAME>" at 16 x 16 pixels native, shown at 12x,
following the style bible. A single small object, centred, no background
other than #15151B, no border. <DESCRIPTION>
```

여러 개를 한 장에 묶고 싶으면: "Draw these as a 4x4 sheet of separate
16x16 icons with 4 pixels of gap" 를 붙인다.

| id | NAME | DESCRIPTION |
|---|---|---|
| broken_mainspring | Broken Mainspring (깨진 태엽) | A coiled watch spring snapped and unwound at one end. |
| worn_shoes | Worn Shoes (닳은 신발) | A pair of shoes with holes worn through the soles. |
| gleaning | Gleaning (거둔 것) | A small bundle of gleaned stalks tied with string. |
| stopped_watch | Stopped Watch (멈춘 회중시계) | A pocket watch, its hands frozen, the one gold spot. |
| settled_dust | Settled Dust (가라앉은 먼지) | A small heap of pale dust settled on a flat surface. |
| sundial | Sundial (해시계) | A small stone sundial with a sharp shadow. |
| night_bell | Night Bell (밤종) | A small hand bell, dark, with a white ring of sound. |
| long_shadow | Long Shadow (긴 그림자) | A tiny post casting a very long shadow across the icon. |
| morning_frost | Morning Frost (아침 서리) | A leaf rimmed with white frost. |
| held_stone | Held Stone (쥐고 있던 돌) | A smooth pebble worn smooth by being held. |
| first_light | First Light (첫 빛) | A sliver of white dawn over a dark horizon line. |
| quick_hand | Quick Hand (빠른 손) | An open pale hand caught mid-motion. |
| short_rope | Short Rope (짧은 끈) | A short length of frayed rope. |
| slow_kettle | Slow Kettle (더딘 주전자) | A small kettle with a thin wisp of steam just starting. |
| practiced_hand | Practiced Hand (익숙해진 손) | A pale hand with worn fingertips, loosely closed. |
| counted_days | Counted Days (헤아린 날) | Tally marks scratched on a scrap of wood. |
| last_ember | Last Ember (마지막 불씨) | A single ember, dull blood red with one gold pixel. |
| full_pockets | Full Pockets (가득 찬 주머니) | A cloth pocket bulging, white light at its mouth. |
| borrowed_coat | Borrowed Coat (빌린 외투) | A coat a size too large, sleeves too long. |
| thin_ice | Thin Ice (살얼음) | A pale sheet of ice with a crack running across it. |
| equality | Equality (평등) | A circle divided into four exactly equal quarters. |

---

## 4. 배경

```
Draw a background for the <SCENE>, following the style bible palette and
pixel rules. 320 x 180 pixels native, shown at 6x (1920 x 1080). No
characters, no text, no UI. Very dark and low-contrast overall, because UI
panels and sprites will sit on top of it — keep the middle and the bottom
third especially quiet. <DESCRIPTION>
```

| SCENE | DESCRIPTION |
|---|---|
| battle screen | An ordinary village street at dusk, seen flat from the side; houses, a well, a lamp post, all in near-black and dim grey-brown. One small wrong thing: a shadow pointing toward the light. |
| room / exploration screen | The inside of an empty ordinary house: a table, a doorway, a window. Still. Dust in the air drawn as a few single pixels. |
| fire (rest) screen | A small fire in the dark, the only warm light; around it, nothing but the edge of a road. |
| title screen | A cracked, empty hourglass very large and far away in a dark sky above a sleeping town, a thin thread of white falling from it toward the roofs. |

---

## 5. 카드 일러스트 (보류)

지금 `card_node.tscn` (148 x 206) 에는 일러스트 자리가 없다. 넣기로 하면
카드 상단에 대략 128 x 72 영역, 네이티브 64 x 36 (2x) 로 잡는 것을 전제로:

```
Draw card illustration art for the card "<NAME>" at 64 x 36 pixels native,
shown at 8x, following the style bible. A tiny, almost symbolic still image —
one object or gesture, no characters' faces, no text. <DESCRIPTION>
```

---

## 받은 그림 쓰는 법 (메모)

- ChatGPT는 "진짜" 격자 픽셀아트를 잘 못 지킨다. 픽셀 크기가 들쭉날쭉하거나
  흐린 경계가 섞여 나오면 그대로 쓰지 말고, 실루엣·구성만 참고해 Aseprite
  등에서 네이티브 크기로 다시 찍는다.
- **도트 크기 통일.** 게임 화면 안의 그림(Warden, Askew, 배경)은 전부
  네이티브 1px = 화면 6px. Warden 24x40 → 144x240, 일반 Askew 32x40 →
  192x240 (적 패널 폭 200 안에 들어감), 보스 64x64 → 384x384, 배경
  320x180 → 1920x1080. 프롬프트의 "shown at 8x" 는 ChatGPT가 픽셀을 크게
  보여주게 하려는 것일 뿐, 게임 배율이 아니다.
- 유물 아이콘·카드 일러스트는 UI 쪽이라 글꼴(16px 비트맵, 2배)에 맞춰
  2배로 그린다. 16x16 아이콘 → 32x32. 화면 그림과 UI가 다른 배율인 것은
  의도된 것이고, 한 그림 안에서만 섞지 않으면 된다.
- Godot 쪽: 텍스처 필터는 Nearest, 스프라이트 위치는 정수 픽셀에 둔다.
  아니면 깔끔하게 찍은 도트도 화면에서 번진다.
- 다시 찍을 때 팔레트는 위 hex 값에 고정. `ui_theme.tres` 의 `Palette`
  색과 같은 값이다.
- 흰색(#F2EEE6) 은 시간의 색이다. 적 스프라이트에서 넓게 쓰면 흰 게이지가
  화면에서 가장 밝은 것이 아니게 된다.
