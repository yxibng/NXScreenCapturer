//
//  TSBitrateHelper.hpp
//  rtc_demo_264_macos
//
//  Created by yxb on 2022/3/31.
//

#ifndef TSBitrateHelper_hpp
#define TSBitrateHelper_hpp

#include <vector>


namespace ts264 {

constexpr static int fpsLevel[] = {1, 10, 15, 24, 30, 60};
constexpr static float fpsFactorList[] = {0.2f, 0.67f, 0.8f, 1.0f, 1.3f, 1.5f, 2.25f};
/*
     * len <=  60: 20.0
     * len <=  80: 13.0
     * len <=  100: 8.0
     * len <=  120: 3.0
     * len <=  240: 2.4
     * len <=  360: 1.6
     * len <=  480: 1.4
     * len <=  720: 1.2
     * len <=  1080: 1
     * len > 1080: 0.8
     * */
constexpr static float baseLenFactorList[] = {20.0f, 13.0f, 8.0f, 3.0f, 2.4f, 1.6f, 1.4f, 1.2f, 1.0f, 0.8f};

static int getBaseBitrate(uint32_t width, uint32_t height, uint32_t fps) {
    int baseLen = 0;
    baseLen = std::min(width, height);

    float baseLenFactor = 0;
    if (baseLen <= 60) {
        baseLenFactor = baseLenFactorList[0];
    } else if (baseLen <= 80) {
        baseLenFactor = baseLenFactorList[1];
    } else if (baseLen <= 100) {
        baseLenFactor = baseLenFactorList[2];
    } else if (baseLen <= 120) {
        baseLenFactor = baseLenFactorList[3];
    } else if (baseLen <= 240) {
        baseLenFactor = baseLenFactorList[4];
    } else if (baseLen <= 360) {
        baseLenFactor = baseLenFactorList[5];
    } else if (baseLen <= 480) {
        baseLenFactor = baseLenFactorList[6];
    } else if (baseLen <= 720) {
        baseLenFactor = baseLenFactorList[7];
    } else if (baseLen <= 1080) {
        baseLenFactor = baseLenFactorList[8];
    } else {
        baseLenFactor = baseLenFactorList[9];
    }

    float fpsFactor;
    if (fps < fpsLevel[0]) {
        fpsFactor = fpsFactorList[0];
    } else if (fps >= fpsLevel[0] && fps < fpsLevel[1]) {
        fpsFactor = fpsFactorList[1];
    } else if (fps >= fpsLevel[1] && fps < fpsLevel[2]) {
        fpsFactor = fpsFactorList[2];
    } else if (fps >= fpsLevel[2] && fps < fpsLevel[3]) {
        fpsFactor = fpsFactorList[3];
    } else if (fps >= fpsLevel[3] && fps < fpsLevel[4]) {
        fpsFactor = fpsFactorList[4];
    } else if (fps >= fpsLevel[4] && fps < fpsLevel[5]) {
        fpsFactor = fpsFactorList[5];
    } else {
        fpsFactor = fpsFactorList[6];
    }

    return std::min(6500 * 1024, int(width * height * baseLenFactor * fpsFactor));
}

static int getLiveBitrate(uint32_t width, uint32_t height, uint32_t fps) {
    return std::min(6500 * 1024, int(getBaseBitrate(width, height, fps) * 1.5));
}

static int getMaxBitrate(uint32_t width, uint32_t height, uint32_t fps) {
    return std::min(6500 * 1024, int(getBaseBitrate(width, height, fps) * 2));
}



};



#endif /* TSBitrateHelper_hpp */
