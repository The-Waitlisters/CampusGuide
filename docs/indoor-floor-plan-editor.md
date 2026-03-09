# Using the Floor Plan Editor for Indoor Maps

This project can load indoor floor data from JSON produced by the [floor-plan-editor](https://github.com/gabrielshufelt/floor-plan-editor) tool. You can use your existing floor images to create navigable room graphs.

## 1. Get the editor

Clone and open the editor (no build step):

```bash
git clone https://github.com/gabrielshufelt/floor-plan-editor.git
cd floor-plan-editor
# Open graph_editor.html in your browser (double-click or drag into Chrome/Firefox)
```

Or open directly:  
[https://github.com/gabrielshufelt/floor-plan-editor/blob/master/graph_editor.html](https://github.com/gabrielshufelt/floor-plan-editor/blob/master/graph_editor.html) → **Raw** → save as `graph_editor.html` and open in a browser.

## 2. Create your floor graph

1. Click **Image** and select your floor plan PNG (e.g. for Hall Building floor 8).
2. Set **Bldg** (e.g. `H`) and **Floor** (e.g. `8`) in the toolbar.
3. Use the **Node** tool and place nodes:
   - **R** (Room) – classrooms, offices (set **Label** to room number, e.g. `H-801`).
   - **D** (Doorway), **W** (Waypoint), **S** (Stair), **E** (Elevator), **B** (Entry/Exit) as needed.
4. Select each node and set **Label** in the properties panel (e.g. `H-801`, `Stairs S1`).
5. Use **Edge** tool to connect nodes (for future pathfinding).
6. **Export** (or Ctrl+S) to download `floor-nav.json`.

Repeat for each floor (e.g. floor 9 → export again).

## 3. Add image dimensions to the JSON

The editor does not export image size. Open the downloaded JSON and add at the **top level**:

```json
{
  "imageWidth": 1024,
  "imageHeight": 1024,
  "nodes": [ ... ],
  "edges": [ ... ]
}
```

Use the actual pixel size of your floor image (e.g. from an image editor or the dimensions shown when you load the image in the editor).

## 4. One file per building: `assets/indoor/<building>.json`

The app loads **one JSON file per building** from `assets/indoor/<building>.json` (e.g. `assets/indoor/H.json` for Hall).

You can either:

- **Option A – One floor per file, then merge:**  
  Export one JSON per floor (e.g. `floor8.json`, `floor9.json`), add `imageWidth` / `imageHeight` to each, then merge into a single file with a `floors` array (see below).

- **Option B – Single-floor building:**  
  Add `imageWidth` and `imageHeight` to the single export and save it as `assets/indoor/H.json`. The loader will treat it as one floor.

### Multi-floor format (`H.json` with several floors)

Structure for a building with multiple floors:

```json
{
  "floors": [
    {
      "level": 8,
      "imageWidth": 1024,
      "imageHeight": 1024,
      "nodes": [
        {
          "id": "H_F8_room_1",
          "type": "room",
          "floor": 8,
          "x": 190,
          "y": 120,
          "label": "H-801",
          "accessible": true
        }
      ],
      "edges": [
        { "source": "H_F8_room_1", "target": "H_F8_doorway_1", "type": "room_to_door", "weight": 10, "accessible": true }
      ]
    },
    {
      "level": 9,
      "imageWidth": 1024,
      "imageHeight": 1024,
      "nodes": [ ... ],
      "edges": [ ... ]
    }
  ]
}
```

Save this as `assets/indoor/H.json`. The app will load it for the Hall building and use it instead of the built-in sample data.

## 5. Optional: floor plan images in the app

To show your PNG as the background in the app, add the images under `assets/indoor/` (e.g. `H_8.png`, `H_9.png`) and extend the app’s floor model to reference them (e.g. by floor level). The current UI draws room polygons; if you add image support, the same coordinates from the editor (normalized with `imageWidth` / `imageHeight`) will align with your images.

## Summary

| Step | Action |
|------|--------|
| 1 | Clone [floor-plan-editor](https://github.com/gabrielshufelt/floor-plan-editor), open `graph_editor.html` in a browser |
| 2 | Load your floor image, set Bldg/Floor, place Room (and other) nodes, set labels, connect with edges, Export JSON |
| 3 | Add `imageWidth` and `imageHeight` to the JSON (match your image size) |
| 4 | Save as `assets/indoor/H.json` (single-floor object or multi-floor with `floors` array) |
| 5 | Run the app; open Hall building → View indoor map; data comes from your JSON |

If `assets/indoor/H.json` is missing or invalid, the app falls back to the built-in sample floors.
