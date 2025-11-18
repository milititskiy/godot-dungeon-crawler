# 🏰 2D Dungeon Raid

A sophisticated 2D dungeon crawler built in **Godot 4.3** featuring grid-based movement, turn-based combat, and an innovative **match-3 style loot collection system**.

![Game Status](https://img.shields.io/badge/Status-In%20Development-yellow)
![Godot Version](https://img.shields.io/badge/Godot-4.3-blue)
![Progress](https://img.shields.io/badge/Progress-85%25-brightgreen)

## 🎮 Game Overview

**2D Dungeon Raid** combines classic dungeon crawler mechanics with modern match-3 gameplay elements. Navigate through a grid-based world, engage in tactical turn-based combat, and collect loot using an innovative chain-selection system with stunning visual effects.

## ✨ Features

### 🕹️ Core Gameplay Systems
- **Grid-Based Movement** (10x10 tiles, 64px with 2px spacing)
- **Dual Control Schemes** (Click-to-move + WASD)
- **A* Pathfinding Algorithm** with Manhattan distance heuristic
- **Smooth Movement Animations** with tweening

### ⚔️ Combat System
- **Turn-Based Battle Mechanics**
- **Two-State Game Mode** (Exploration ↔ Battle)
- **PopupPanel Combat Menus** with Attack/Steal options
- **Enemy Health Persistence** across multiple encounters
- **Automatic Battle Initiation** when approaching enemies

### 💎 Advanced Loot Collection
- **Hierarchical Loot Categories**: Weapons, Armor, Potions, Currency, Enemies
- **Match-3 Style Chain Selection**: Click and drag connected loot of same type
- **Progressive "Tail System"**: Comet tail visual effects with staggered collection timing
- **Backtrace Selection System**: Dynamic chain editing by clicking previous items
- **Rich Visual Feedback**: Green highlighting, red pathlines, fade animations

### 🤖 Enemy AI
- **Pathfinding-Enabled Enemies** using A* algorithm
- **Dynamic Chase Behavior** (6-tile detection range)
- **Health System** with damage tracking and persistence
- **Battle Integration** with automatic loot generation

### 🎨 Visual Systems
- **Custom Sprite Integration** (PNG assets with transparency handling)
- **Coordinate Conversion** (world-to-screen for UI positioning)
- **Dynamic Visual Effects** (fade animations, scaling, comet tails)
- **Path Visualization** (red lines showing movement paths)
- **Configurable Timing System** via LootConfig.gd

## 🛠️ Technical Architecture

### **Core Components**
| Component | Lines | Purpose |
|-----------|-------|---------|
| `GameField.gd` | 1400+ | Central controller managing all game systems |
| `Player.gd` | 379 | Character movement and combat interactions |
| `Enemy.gd` | 180+ | AI behavior and pathfinding |
| `LootItem.gd` | 129 | Interactive loot with visual feedback |
| `LootConfig.gd` | - | Configuration for collection timing/effects |
| `PathfinderGrid.gd` | - | A* pathfinding implementation |

### **Key Data Structures**
- `loot_chain`: Selected loot items for collection
- `pending_collections`: Queue for progressive loot collection
- `enemy_health`: Health tracking across battles
- `chain_lines`: Visual path lines management

## 🚀 Development Progress

### ✅ **Completed Systems (85%)**
- [x] **Grid Navigation** - Smooth pathfinding with A* algorithm
- [x] **Battle System** - Turn-based combat with proper state management
- [x] **Loot Collection** - Progressive collection with comet tail effects
- [x] **Enemy Health** - Persistence across multiple encounters
- [x] **Chain Selection** - Backtrace editing capability
- [x] **Visual Effects** - Highlighting, animations, pathlines
- [x] **Memory Management** - Proper object lifecycle handling
- [x] **Sprite Integration** - Custom PNG assets with transparency fixes
- [x] **Combat Menus** - PopupPanel positioning with coordinate conversion

### 🟡 **Partially Implemented**
- [ ] **Steal Mechanics** (placeholder functionality exists)
- [ ] **Game Balance** (damage values, timing parameters need tuning)
- [ ] **Advanced AI Patterns** (basic chase behavior implemented)

### 🔄 **Future Development**
- [ ] **Player Progression** (levels, stats, inventory system)
- [ ] **Multiple Levels** (procedural generation or hand-crafted)
- [ ] **Advanced Enemy Types** (different behaviors, abilities)
- [ ] **Sound System** (SFX and background music)
- [ ] **Save/Load System** (game state persistence)

## 🐛 Known Issues & Solutions

### **Recently Fixed**
- ✅ **Memory Leaks**: "Previously freed" object access errors
- ✅ **Combat Menu Positioning**: PopupPanel coordinate conversion
- ✅ **State Transition Cleanup**: Red pathlines persisting after battle
- ✅ **Sprite Transparency**: PNG transparency checker pattern

### **Current Issues**
- 🔧 Sprite transparency handling may need refinement
- 🔧 Combat steal mechanics need full implementation

## 📁 Project Structure

```
2d_godot_dungeon_raid/
├── assets/
│   └── sprites/
│       ├── items/          # health_potion.png, sword.png, etc.
│       └── enemies/        # enemy.png
├── scenes/
│   ├── GameField.tscn     # Main game scene
│   ├── Player.tscn        # Player character
│   ├── Enemy.tscn         # Enemy template
│   └── ...
├── scripts/
│   ├── GameField.gd       # Main game controller
│   ├── Player.gd          # Player movement & combat
│   ├── Enemy.gd           # Enemy AI & pathfinding
│   ├── LootItem.gd        # Loot interaction & visuals
│   └── ...
└── project.godot
```

## 🎯 Development Milestones

### **Phase 1: Foundation** ✅
- Basic grid system and movement
- Player controls and pathfinding
- Obstacle placement and collision

### **Phase 2: Combat System** ✅  
- Turn-based battle mechanics
- Enemy AI and behavior
- Health system implementation

### **Phase 3: Loot System** ✅
- Match-3 style selection
- Progressive collection effects
- Visual feedback systems

### **Phase 4: Polish & Assets** ✅
- Custom sprite integration
- UI improvements and positioning
- Memory management and bug fixes

### **Phase 5: Enhancement** 🔄
- Steal mechanics completion
- Game balance and difficulty tuning
- Additional content and features

## 🚦 Getting Started

### **Prerequisites**
- Godot Engine 4.3+
- Basic knowledge of GDScript (optional for playing)

### **Running the Game**
1. Clone this repository
2. Open `project.godot` in Godot Engine
3. Press F5 or click "Play" to start the game
4. Use WASD or click to move
5. Right-click adjacent enemies to enter combat
6. Click and drag matching loot items to create chains

### **Controls**
- **Movement**: WASD keys or click-to-move
- **Combat**: Right-click adjacent enemies
- **Loot Selection**: Click and drag matching items
- **Chain Editing**: Click previous items in chain to edit

## 🤝 Contributing

This project showcases advanced Godot 4 development techniques including:
- Complex state management systems
- Advanced coordinate transformations
- Progressive animation systems
- Dynamic UI positioning
- Memory management best practices

## 📊 Technical Highlights

- **Sophisticated coordinate systems** handling world/screen/grid conversions
- **Progressive collection timing** creating satisfying comet tail effects  
- **Dynamic selection system** allowing real-time chain editing
- **Robust error handling** preventing crashes from freed objects
- **Modular architecture** with clear separation of concerns

## 🎮 Gameplay Demo

The game demonstrates a complete gameplay loop:
1. **Exploration**: Navigate the grid world
2. **Combat**: Engage enemies in turn-based battles  
3. **Collection**: Gather loot using match-3 mechanics
4. **Progression**: Enemy health persists, creating strategic depth

---

**Development Status**: Active | **Last Updated**: November 2025 | **Engine**: Godot 4.3