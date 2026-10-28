#include "VoiceThingAudio.c"
#include <assert.h>
#include <stdio.h>

int main(void) {
    AudioServerPlugInDriverRef driver = gAudioServerPlugInDriverRef;
    AudioObjectPropertyAddress address = { kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    CFStringRef uid = NULL;
    UInt32 size = 0;
    assert(NullAudio_GetDevicePropertyData(driver, kObjectID_Device, 0, &address, 0, NULL, sizeof(uid), &size, &uid) == noErr);
    assert(CFEqual(uid, CFSTR("com.voicething.audio.device")));
    address.mSelector = kAudioDevicePropertyDeviceCanBeDefaultDevice;
    address.mScope = kAudioObjectPropertyScopeOutput;
    UInt32 value = 99;
    assert(NullAudio_GetDevicePropertyData(driver, kObjectID_Device, 0, &address, 0, NULL, sizeof(value), &size, &value) == noErr);
    assert(value == 0);
    address.mScope = kAudioObjectPropertyScopeInput;
    assert(NullAudio_GetDevicePropertyData(driver, kObjectID_Device, 0, &address, 0, NULL, sizeof(value), &size, &value) == noErr);
    assert(value == 1);
    assert(NullAudio_StartIO(driver, kObjectID_Device, 0) == noErr);
    AudioServerPlugInIOCycleInfo cycle = {0};
    cycle.mOutputTime.mSampleTime = 4096;
    cycle.mInputTime.mSampleTime = 4096 + VT_LATENCY;
    float output[1024], input[1024];
    for (int i = 0; i < 1024; i++) output[i] = sinf((float)i * 0.1f) * 0.3f;
    assert(NullAudio_DoIOOperation(driver, kObjectID_Device, kObjectID_Stream_Output, 0, kAudioServerPlugInIOOperationWriteMix, 512, &cycle, output, NULL) == noErr);
    assert(NullAudio_DoIOOperation(driver, kObjectID_Device, kObjectID_Stream_Input, 0, kAudioServerPlugInIOOperationReadInput, 512, &cycle, input, NULL) == noErr);
    assert(memcmp(input, output, sizeof(input)) == 0);
    gMute_Input_Master_Value = true;
    NullAudio_DoIOOperation(driver, kObjectID_Device, kObjectID_Stream_Input, 0, kAudioServerPlugInIOOperationReadInput, 512, &cycle, input, NULL);
    for (int i = 0; i < 1024; i++) assert(input[i] == 0);
    gMute_Input_Master_Value = false;
    gVolume_Input_Master_Value = -6;
    NullAudio_DoIOOperation(driver, kObjectID_Device, kObjectID_Stream_Input, 0, kAudioServerPlugInIOOperationReadInput, 512, &cycle, input, NULL);
    for (int i = 0; i < 1024; i++) assert(fabsf(input[i] - output[i] * powf(10, -6.0f / 20)) < 0.00001f);
    assert(NullAudio_StopIO(driver, kObjectID_Device, 0) == noErr);
    puts("VoiceThing driver: UID, input/output defaults, I/O callbacks, stereo loopback, mute, gain and start/stop passed.");
    return 0;
}
