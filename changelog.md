# Changelog

All notable changes to this project will be documented in this project.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.22] - 21-07-2025

### Added

-  Multiple monitor is possible for future extensions. Current setup uses two 4x4 monitor.
- Chatbox to receive Toast message, speaker to play sound, and redstone relay to output redstone pulses when colony is under attack. In game name (ign) in main.lua file should be changed for getting toast messages
- One monitor shows citizen information and Summary for the colony and another one for tracking requests.
- Crafting of requested items can be toggled in main.lua file. local crafting_enabled = true -- toggle for auto crafting of requests


### Changed

- To keep track of the code functions got seperated into different files.
- Storage and export item call method.

### Removed

- Dependency of reading NBT data for Domum items has been removed due to absense of NBT data received from Bridge.


### Fixed

- Repetitive crafting due to delay of supply chain has been fixed by taking account of chest content
- NBT data is used only when supply without depending on it.

### TODO 

-  A lot of things... Thanks for developers of all the mods and all the mods 10 for making it more fun for us.
