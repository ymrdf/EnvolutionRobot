# 🤖 Robot FPS

> An arcade-style robot FPS environment for reinforcement learning built with Godot.

https://github.com/user-attachments/assets/2086cf9e-ead8-4e6b-88b2-0147e3c2d882

---

## 🎯 Goal

Train an AI agent to hit enemy robots while avoiding incoming fire. Survive, aim, and dominate the arena!

---

## 👁️ Observations

The agent observes the world using **two RGB camera sensors** (stereo vision) plus its current HP.

- **`right_eye`**: RGB camera pixel encoding from the robot’s `RightEye` camera mount (rendered at `320×300`)
- **`left_eye`**: RGB camera pixel encoding from the robot’s `LeftEye` camera mount (rendered at `320×300`)
- **`hp`**: Current hit points as a single scalar in a 1D array (`[hp]`)

These observations are produced by `RobotAIController` via `RGBCameraSensor3D` sensors attached at runtime.

---

## 🎮 Action Space

The agent has **4 discrete actions** available:

| Action                | Size | Type     | Description                |
| --------------------- | ---- | -------- | -------------------------- |
| `accelerate_forward`  | 3    | discrete | Move forward/backward/stay |
| `accelerate_sideways` | 3    | discrete | Strafe left/right/stay     |
| `turn`                | 3    | discrete | Rotate left/right/stay     |
| `shoot`               | 2    | discrete | Fire weapon or hold        |

```gdscript
func get_action_space() -> Dictionary:
    return {
        "accelerate_forward": {"size": 3, "action_type": "discrete"},
        "accelerate_sideways": {"size": 3, "action_type": "discrete"},
        "turn": {"size": 3, "action_type": "discrete"},
        "shoot": {"size": 2, "action_type": "discrete"},
    }
```

---

## 🏆 Rewards & Episode Conditions

### Rewards

| Event                          | Reward |
| ------------------------------ | ------ |
| Hit another robot              | `+1`   |
| Hit robot in protection period | `0`    |

### Episode End

- Each robot has **2 HP**
- Episode ends when HP reaches **0** (after taking 2 shots)
- On death, the robot **respawns** at a random free position on the map

---

## 🚀 Getting Started

### Running Inference / Testing

1. Open the project in **Godot Editor**
2. Choose a scene:
   - `res://scenes/testing_scene/testing_scene.tscn` → **AI vs AI**
   - `res://scenes/testing_scene/testing_scene_human_vs_ai.tscn` → **Human vs AI**
3. Press `F6` to start the scene

### Keyboard Controls (Human vs AI Mode)

| Action            | Keys                   |
| ----------------- | ---------------------- |
| Move Forward/Back | `W` / `S` or `↑` / `↓` |
| Strafe Left/Right | `A` / `D`              |
| Rotate            | `←` / `→`              |
| Shoot             | `Space`                |

---

## 📁 Project Structure

```
RobotFPS/
├── scenes/
│   ├── robot/           # Robot agent and AI controller
│   ├── playing_area/    # Game arena and manager
│   ├── testing_scene/   # Test environments
│   └── block/           # Arena obstacles
└── readme.md
```

---

## 📝 License

Part of the [Godot RL Agents Examples](https://github.com/edbeeching/godot_rl_agents_examples) project.
