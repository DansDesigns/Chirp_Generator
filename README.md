# Chirp_Generator
Frequency Modulation Tool to generate beeps, chirps & computer noises


<img width="1165" height="1166" alt="Screenshot from 2026-03-23 01-08-42" src="https://github.com/user-attachments/assets/c78d7b31-4c64-4bf1-83ff-fc44ce31d6cb" />

* To install on Linux:

from terminal:
```
git clone https://github.com/DansDesigns/Chirp_Generator.git 

cd Chirp_Generator

chmod +x ./install_chirpgen.sh && ./install_chirpgen.sh
```

from file browser:
```
enter extracted folder

right click install_chirpgen.sh

select properties

set to run as program/allow to execute as program & close

double click install_chirpgen.sh
```

First run auto-launches & installs a .desktop shortcut to the app folder (use your app list to launch)


========================================

* To install on Windows:
```
git clone this repo (or download as zip & extract)
```

To be continued....



=========================================

* using .h files with Arduino IDE:

place the .h file in the same folder as your .ino sketch,
reference them as an import at the top of your .ino file:
```
#include "chirp.h"
#include "ring.h"
…
```

use dacWrite(FILENAME) to play .h files

