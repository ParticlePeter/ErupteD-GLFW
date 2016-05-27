
import std.stdio;
import std.range;
import std.array;
import std.algorithm;
import std.exception;
import std.conv;
import std.string;

import erupted;
import vulkan_glfw3;


private void enforceVK(VkResult res) {
	enforce(res == VkResult.VK_SUCCESS, res.to!string);
}

extern( C ) void key_callback( GLFWwindow * window, int key, int scancode, int val, int mod ) nothrow {
	if( key == GLFW_KEY_ESCAPE && val == GLFW_PRESS ) {
		glfwSetWindowShouldClose( window, GLFW_TRUE );
	}
}


int main() {

	// load global level functions 
	VulkanGLFW3.load();
	glfwInit();

	// check if Vulkan is available on this machine
	if( !glfwVulkanSupported()) {
		writeln( "Vulkan is not supported on this Device." );
		return 0;
	}

	// glfw window specification
	glfwWindowHint( GLFW_CLIENT_API, GLFW_NO_API );
	GLFWwindow* window = glfwCreateWindow( 720, 480, "GLFW3 Vulkan Erupted", null, null );
	glfwSetKeyCallback( window, &key_callback );
	//glfwMakeContextCurrent( window );

	// load global level functions with glfw
	loadGlobalLevelFunctions( cast( typeof( vkGetInstanceProcAddr ))
		glfwGetInstanceProcAddress( null, "vkGetInstanceProcAddr" ));
	
	// prepare VkInstance creation
	VkApplicationInfo appInfo = {
		pApplicationName: "Vulkan Test with GLFW3",
		apiVersion: VK_MAKE_VERSION( 1, 0, 3 ),
	};
	
	// get the extensions required for for a glfw window with vulkan surface
	uint glfwRequiredExtensionsCount;
	auto glfwRequiredExtensions = glfwGetRequiredInstanceExtensions( &glfwRequiredExtensionsCount );

	// assuming that the extensions are available on this machine, but this should be checked 
	VkInstanceCreateInfo instInfo = {
		pApplicationInfo		: &appInfo,
		enabledExtensionCount	: glfwRequiredExtensionsCount,
		ppEnabledExtensionNames	: glfwRequiredExtensions,
	};
	
	// create the vulkan instance
	VkInstance instance;
	vkCreateInstance( &instInfo, null, &instance ).enforceVK;

	// destroy the instance at scope exist
	scope( exit ) {
		writeln( "Scope exit: destroying instance" );
		if( instance != VK_NULL_HANDLE ) {
			vkDestroyInstance( instance, null );
		}
	}

	// create the window surface with a VkSurfaceKHR
	VkSurfaceKHR surface; 
	glfwCreateWindowSurface( instance, window, null, &surface ).enforceVK;
	scope( exit ) {
		writeln( "Scope exit: destroying surface" );
		vkDestroySurfaceKHR( instance, surface, null );
	}

	// load instance level functions
	loadInstanceLevelFunctions( instance );
	
	// enumerate physical devices
	uint numPhysDevices;
	enforceVK(vkEnumeratePhysicalDevices(instance, &numPhysDevices, null));
	if (numPhysDevices == 0) {
		stderr.writeln("No physical devices available.");
		return 1;
	}
	
	writeln;
	writeln("Found ", numPhysDevices, " physical device(s)\n==========================");
	writeln;
	
	// acquire physical devices
	auto physDevices = new VkPhysicalDevice[](numPhysDevices);
	vkEnumeratePhysicalDevices(instance, &numPhysDevices, physDevices.ptr).enforceVK;
	
	// print information about physical devices
	foreach(i, physDevice; physDevices) {
		VkPhysicalDeviceProperties properties;
		vkGetPhysicalDeviceProperties(physDevice, &properties);
		writeln("Physical device ", i, ": ", properties.deviceName.ptr.fromStringz);
		writeln("API Version: ", VK_VERSION_MAJOR(properties.apiVersion), ".", VK_VERSION_MINOR(properties.apiVersion), ".", VK_VERSION_PATCH(properties.apiVersion));
		writeln("Driver Version: ", properties.driverVersion);
		writeln("Device type: ", properties.deviceType);
		writeln;
	}

	// for simplicity the first found physical device will be used

	// enumerate queues of first physical device
	uint numQueues;
	vkGetPhysicalDeviceQueueFamilyProperties(physDevices[0], &numQueues, null);
	assert(numQueues >= 1);

	auto queueFamilyProperties = new VkQueueFamilyProperties[](numQueues);
	vkGetPhysicalDeviceQueueFamilyProperties(physDevices[0], &numQueues, queueFamilyProperties.ptr);
	assert(numQueues >= 1);	// numQueues can be different than the first time

	// find print information about queue families and find graphics queue family index
	uint graphicsQueueFamilyIndex = uint.max;
	foreach(i, const ref properties; queueFamilyProperties) {
		writeln("Queue Family ", i);
		writeln("\tQueues in Family         : ", properties.queueCount);
		writeln("\tQueue timestampValidBits : ", properties.timestampValidBits);

		if (properties.queueFlags & VK_QUEUE_GRAPHICS_BIT) {
			writeln("\tVK_QUEUE_GRAPHICS_BIT");
			if (graphicsQueueFamilyIndex == uint.max) {
				graphicsQueueFamilyIndex = i;
			}
		}

		if (properties.queueFlags & VK_QUEUE_COMPUTE_BIT)
			writeln("\tVK_QUEUE_COMPUTE_BIT");

		if (properties.queueFlags & VK_QUEUE_TRANSFER_BIT)
			writeln("\tVK_QUEUE_TRANSFER_BIT");

		if (properties.queueFlags & VK_QUEUE_SPARSE_BINDING_BIT)
			writeln("\tVK_QUEUE_SPARSE_BINDING_BIT");

		writeln;
	}

	// if no graphics queue family was found use the first available queue family
	if (graphicsQueueFamilyIndex == uint.max)  {
		writeln("VK_QUEUE_GRAPHICS_BIT not found. Using queue family index 0");
		graphicsQueueFamilyIndex = 0;
	} else {
		writeln("VK_QUEUE_GRAPHICS_BIT found at queue family index ", graphicsQueueFamilyIndex);
	}

	writeln;

	// prepare VkDeviceQueueCreateInfo for logical device creation
	float[1] queuePriorities = [ 1.0f ];
	VkDeviceQueueCreateInfo queueCreateInfo = {
		queueCount			: 1,
		pQueuePriorities 	: queuePriorities.ptr,
		queueFamilyIndex	: graphicsQueueFamilyIndex,
	};

	// prepare logical device creation
	VkDeviceCreateInfo deviceCreateInfo = {
		queueCreateInfoCount	: 1,
		pQueueCreateInfos		: &queueCreateInfo,
	};

	// create the logical device
	VkDevice device;
	enforceVK(vkCreateDevice(physDevices[0], &deviceCreateInfo, null, &device));
	writeln("Logical device created");

	// destroy the device at scope exist
	scope(exit) {
		writeln( "Scope exit: draining work and destroying logical device");
		if( device != VK_NULL_HANDLE ) {
			vkDeviceWaitIdle(device);
			vkDestroyDevice(device, null);
		}
	}

	// load all Vulkan functions for the device
	loadDeviceLevelFunctions(device);

	// alternatively load all Vulkan functions for all devices
	//EruptedLoader.loadDeviceLevelFunctions(instance);

	// get the graphics queue to submit command buffers
	VkQueue queue;
	vkGetDeviceQueue(device, graphicsQueueFamilyIndex, 0, &queue);
	writeln("Graphics queue retrieved");

	// produce some mind-blowing visuals
	//...

	while( !glfwWindowShouldClose( window )) {
		glfwSwapBuffers(window);
		glfwPollEvents();
	}

	writeln;

	return 0;
}
