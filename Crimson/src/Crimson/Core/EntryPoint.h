#pragma once

#include "Core.h"
#include "Application.h"

#if defined(CN_PLATFORM_WINDOWS) || defined(CN_PLATFORM_MACOS)

int main(int argc, char** argv)
{
    Crimson::Log::Init();

    CN_PROFILE_BEGIN_SESSION("Init", "CrimsonProfile-Startup.json");
    auto app = Crimson::CreateApplication();
    CN_PROFILE_END_SESSION();

    CN_PROFILE_BEGIN_SESSION("Runtime", "CrimsonProfile-Runtime.json");
    app->Run();
    CN_PROFILE_END_SESSION();

    CN_PROFILE_BEGIN_SESSION("Shutdown", "CrimsonProfile-Shutdown.json");
    delete app;
    CN_PROFILE_END_SESSION();

    return 0;
}

#else
    #error Crimson only supports Windows and macOS Entry Points currently!
#endif