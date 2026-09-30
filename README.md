# Run OpenFusion(Offline) on Android

# Prerequisites
- Download the latest OpenfusionLauncher(Windows Portable) on PC.  https://github.com/OpenFusionProject/OpenFusionLauncher/releases
- Download the latest Openfusion Server(Windows Academy/Original) on PC. https://github.com/OpenFusionProject/OpenFusion/releases
- Download and install Winlator and/Gamehub on the Android device. https://github.com/Dlegend123/OpenFusionAndroid/blob/master/OpenFusion.ahk

1. Create an OpenFusion folder.
2. Copy the extracted OpenFusionLauncher-main folder to the OpenFusion folder.
3. Download offline cache
- Click the gear button at the bottom left
- Click on the Game Builds tab.
- Click the download button in the offline cache column for the specific build.
- Click the blue button beside the download button.
- In the new window copy the name of the current folder.
4. Rename OpenFusionLauncher-main to OpenFusionLauncher.
5. Create an OpenFusionServer folder in the OpenFusion folder and copy the extracted contents of Openfusion Server(Windows Academy/Original) to it
6. Copy the config.ini file from the OpenFusion Server and paste it into the OpenFusion folder. Add the following lines to the end of the file:
	```
	# ===========================================================
	# Launcher Configurations
	# ===========================================================

	[launcher:local]
	# full path to the OpenFusionServer executable
	server = OpenFusionServer\winfusion.exe
 
	# full path to the OpenFusionLauncher executable
	launcher = OpenFusionLauncher\ffrunner.exe

	# path to the offline_cache directory
	OpenFusionLauncher\offline_cache\6543a2bb-d154-4087-b9ee-3c8aa778580a

	# optional: username for automatic login (if supported)
	#username = dummy

	# optional: authentication token for automatic login
	#token = dummy

	# optional: custom log file (ffrunner uses internal default if omitted)
	log_file = ffrunner_output.txt

	# optional: forces vulkan to be used
	force_vulkan = true

 	# optional: allows opening the launcher in fullscreen
 	fullscreen = true
	```
7. Move the OpenFusion folder to your Android Device.

## OpenFusion directory
![alt text](https://github.com/Dlegend123/OpenFusionAndroid/blob/master/OpenFusion.png)

## OpenFusion/OpenFusionLauncher directory
![alt text](https://github.com/Dlegend123/OpenFusionAndroid/blob/master/OpenFusionLauncher.png)

## OpenFusion/OpenFusionServer directory
![alt text](https://github.com/Dlegend123/OpenFusionAndroid/blob/master/OpenFusionServer.png)

## Winlator

## Gamehub
- Import the OpenFusion.exe file in Gamehub.
- Can use wine10.0-x64-2 as the `Compatibility Layer`.
- Can use Performance as the `Translation Params`.
- `DXVK Version` varies depending on the GPU driver used.
