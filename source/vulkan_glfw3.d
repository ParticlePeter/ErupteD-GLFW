public import derelict.glfw3;
import erupted;

const GLFW_TRUE = 1;
const GLFW_FALSE = 0;

extern(C) @nogc nothrow {
	enum GLFW_NO_API = 0;

	alias GLFWvkproc = void function();

	alias da_glfwVulkanSupported = int function();
	alias da_glfwGetRequiredInstanceExtensions = const(char*)* function(uint*);
	alias da_glfwGetPhysicalDevicePresentationSupport = int function(VkInstance, VkPhysicalDevice, uint);
	alias da_glfwGetInstanceProcAddress = GLFWvkproc function(VkInstance, const(char)*);
	alias da_glfwCreateWindowSurface = VkResult function(VkInstance, GLFWwindow*, const(VkAllocationCallbacks)*, VkSurfaceKHR*);
}

__gshared {
	da_glfwVulkanSupported glfwVulkanSupported;
	da_glfwGetRequiredInstanceExtensions glfwGetRequiredInstanceExtensions;
	da_glfwGetPhysicalDevicePresentationSupport glfwGetPhysicalDevicePresentationSupport;
	da_glfwGetInstanceProcAddress glfwGetInstanceProcAddress;
	da_glfwCreateWindowSurface glfwCreateWindowSurface;
}

final class VulkanGLFW3Loader : DerelictGLFW3Loader {
	public this() {
		super();
	}

	protected override void loadSymbols() {
		super.loadSymbols();

		bindFunc(cast(void**)&glfwVulkanSupported,"glfwVulkanSupported");
		bindFunc(cast(void**)&glfwGetRequiredInstanceExtensions,"glfwGetRequiredInstanceExtensions");
		bindFunc(cast(void**)&glfwGetPhysicalDevicePresentationSupport,"glfwGetPhysicalDevicePresentationSupport");
		bindFunc(cast(void**)&glfwGetInstanceProcAddress,"glfwGetInstanceProcAddress");
		bindFunc(cast(void**)&glfwCreateWindowSurface,"glfwCreateWindowSurface");
	}
}

__gshared VulkanGLFW3Loader VulkanGLFW3;


shared static this() {
	VulkanGLFW3 = new VulkanGLFW3Loader();
}

void list_glfw_required_extensions() {
	uint32_t count;
	auto extensions = glfwGetRequiredInstanceExtensions( &count );
	import core.stdc.stdio : printf;
	printf( "Required Extension count: %u\n", count );
	foreach( i; 0..count ) {
		printf("%s\n", extensions[i]);
	}
}