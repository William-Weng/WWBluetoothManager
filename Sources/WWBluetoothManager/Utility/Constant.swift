//
//  Constant.swift
//  WWBluetoothManager
//
//  Created by WilliamWeng on 2026/5/4.
//

import CoreBluetooth

// MARK: - Central事件狀態常數化
public extension WWBluetoothManager {
    
    /// CentralManager 相關的事件狀態，用於 `centralManager(_:status:)` 委派方法。
    /// 這些事件來自 `CBCentralManagerDelegate`，代表 Bluetooth 中央設備管理器的核心操作：
    /// - 狀態更新（開關、權限等）
    /// - 設備掃描發現
    /// - 設備連線/斷線狀態變化
    /// **使用情境**：處理掃描、連線等中央管理器層級的事件。
    enum CentralStatus {
        
        case stateUpdated(state: CBManagerState)                                                        // Bluetooth 狀態更新（`.poweredOn`, `.poweredOff`, `.unauthorized` 等）
        case discovered(result: Central.ScanResult)                                                     // 掃描期間發現新的周邊設備
        case connected(peripheral: CBPeripheral)                                                        // 成功連接到周邊設備，開始服務發現流程
        case disconnected(peripheral: CBPeripheral, error: Error?)                                      // 周邊設備斷線，可能因使用者手動斷開、設備離開範圍或錯誤
        case failedToConnect(peripheral: CBPeripheral, error: Error?)                                   // 連線失敗，可能因超時、設備拒絕連線或錯誤
    }
    
    /// CBPeripheral 相關的事件狀態，用於 `centralManager(_:peripheral:status:)` 委派方法。
    /// 這些事件來自 `CBPeripheralDelegate`，代表已連線周邊設備的詳細操作：
    /// - 服務和特性發現
    /// - 通知狀態變化
    /// - 資料讀寫完成
    /// **使用情境**：處理特定設備的 GATT 服務操作和資料通訊。
    enum PeripheralStatus {
        
        case discoveredServices(services: [CBService])                                                  // 成功發現設備的所有服務
        case discoveredCharacteristics(service: CBService, characteristics: [CBCharacteristic])         // 某個服務的特性發現完成
        case notificationStateUpdated(characteristic: CBCharacteristic, error: Error?)                  // 通知狀態更新（啟用/停用），可能伴隨錯誤
        case characteristicValueUpdated(characteristic: CBCharacteristic, data: Data?, error: Error?)   // 特性值更新（通知/指示觸發），包含接收到的資料
        case characteristicWriteCompleted(characteristic: CBCharacteristic, error: Error?)              // 特性寫入操作完成，可能伴隨錯誤
        case characteristicDiscoveryFailed(service: CBService, error: Error?)                           // 特性發現失敗
        case serviceDiscoveryFailed(error: Error?)                                                      // 服務發現失敗
    }
}

// MARK: - Client事件狀態常數化
public extension WWBluetoothManager {
    
    /// 代表藍牙 Client 運作過程中產生的各種狀態與事件 => 透過訂閱這些事件，外部開發者可以即時掌握藍牙連線的生命週期與數據流向。
    enum ClientEvent {
        
        case stateChanged(CBManagerState)                                                               // 藍牙硬體狀態變更 (例如：poweredOn, poweredOff, resetting)
        case discovered(Device)                                                                         // 發現周邊設備
        case connected(Device)                                                                          // 成功連線至周邊設備
        case disconnected(Device?, Error?)                                                              // 設備斷線。回傳該設備與斷線原因 (若為 nil 代表正常斷線)
        case servicesDiscovered(Device, [CBUUID])                                                       // 已成功發現設備的所有服務 (Services)
        case characteristicsDiscovered(CBUUID, [CBUUID])                                                // 已成功發現指定服務下的所有特徵值 (Characteristics)
        case notificationEnabled(CBUUID)                                                                // 特定特徵值的通知功能已開啟 (Notification/Indication enabled)
        case valueUpdated(CBUUID, Data)                                                                 // 接收到來自藍牙裝置的數據更新
        case writeCompleted(CBUUID, Error?)                                                             // 寫入資料操作已完成。回傳錯誤以標記是否發生失敗
        case failed(Error)                                                                              // 操作失敗。包含所有階段（掃描、連線、發現、讀寫）的錯誤 => 建議配合 ClientError 進行類型匹配與處理
    }
    
    /// 代表藍牙 Client 運作過程中產生的各種錯誤
    enum ClientError: Error {
        
        case invalidUUID                                                                                // 無效的 UUID 格式，無法轉換為 CBUUID
        case peripheralNotConnected                                                                     // 設備尚未連線或連線已斷開
        case characteristicNotFound                                                                     // 特徵值不可用（未發現、無權限或該設備不支援）
        case encodingFailed                                                                             // 字串轉 Data 編碼失敗 (例如：使用了不支援該字元集的編碼)
        case operationFailed(Error)                                                                     // 底層藍牙作業錯誤（關聯到底層的錯誤訊息）
    }
}

// MARK: - 檔案傳輸
public extension WWBluetoothManager {
    
    /// 檔案傳輸協議的封包型別 => 設計概念參考 TLS/SSL handshake：先做握手協商，再進入資料傳輸，最後做完成確認 / 每一個 case 都代表一種「控制訊息」或「資料訊息」。
    enum FileTransferRecordType: UInt8 {
        
        case clientHello = 0x01     // 傳送端發起傳檔請求 => 類似 TLS 的 ClientHello
        case serverHello = 0x02     // 接收端回覆已收到傳檔請求，並同意建立此次傳輸會話 => 類似 TLS 的 ServerHello
        case ready = 0x03           // 傳送端確認握手完成，準備開始傳送資料片段
        case data = 0x04            // 檔案內容的實際資料片段
        case ack = 0x05             // 接收端確認已收到某個資料片段 (ACK = Acknowledgement)
        case finish = 0x06          // 傳送端表示檔案資料已經全部送完 => 表示所有 `.data` 都已送出
        case finishAck = 0x07       // 接收端確認整個檔案已成功接收並完成重組 => 類似傳輸流程中的最終完成確認
        case error = 0x08           // 傳輸過程中發生錯誤 => 可表示握手失敗、資料缺片、格式錯誤、狀態不一致等問題
    }
    
    /// 檔案傳輸狀態機目前所處的階段 => `FileTransferRecordType` = 「收到 / 送出的封包是什麼」 / `FileTransferPhase` = 「整個傳檔流程現在走到哪裡」
    enum FileTransferPhase: Equatable {
        
        case idle                           // 尚未開始傳輸 => 初始狀態，或重置後的待命狀態。
        case waitingServerHello             // 已送出 `clientHello`，等待接收端回覆 `serverHello` => 這表示傳送端正在等待對方接受此次傳輸會話
        case waitingReady                   // 已完成前半段握手，等待進入正式傳輸狀態 => 接收端剛收到 `clientHello`，準備等待 `ready` / 傳送端剛收到 `serverHello`，即將送出 `ready`
        case sendingData                    // 正在傳送或接收資料片段 => 進入此狀態後，通常會持續處理 `.data` 與 `.ack`，直到所有 chunk 傳輸完成
        case waitingFinishAck               // 所有資料片段都已送出，等待接收端回覆 `finishAck` => 傳送端在送出 `finish` 後，會停留在這個狀態，直到對方確認整個檔案已完整接收
        case receivingData                  // 正在接收資料片段 => 這個狀態通常出現在接收端，表示目前正在累積多個 `data` chunk，等待重組完整檔案
        case completed                      // 傳輸已成功完成 => 傳送端或接收端在整個流程結束後都可以進入此狀態
        case failed(FileTransferError)      // 傳輸失敗 => 會附帶錯誤描述，用來表示此次傳輸失敗的原因
    }
    
    /// 檔案傳輸錯誤
    ///
    /// 表示本次檔案傳輸過程中發生的領域錯誤，
    /// 用於 `WWBluetoothManager.FileTransferController` 的狀態機與回調。
    enum FileTransferError: Error, Equatable {
        
        case writeFailed(String)            // 寫入藍牙 characteristic 失敗
        case updateFailed(String)           // characteristic 資料更新失敗
        case invalidRecord                  // 收到的傳輸記錄格式無法解碼或無效
        case missingChunks                  // 所有資料切片尚未集齊，無法組成完整檔案
        case peerReturnedError              // 對端回傳了錯誤訊號，表示傳輸異常
        case invalidTransferId              // 收到的傳輸 ID 與本端不符，可能為不屬於本次傳輸的封包
        case invalidPhase                   // 傳輸狀態機進入非法狀態，表示內部流程錯誤
        case missingCharacteristic          // 所需的藍牙 characteristic 不存在（例如 data / control characteristic 為 nil）
    }
}

// MARK: - ServiceUUIDType
public extension WWBluetoothManager {
    
    /// [周邊設備的UUID代號類型](https://github.com/Eronwu/Getting-Started-with-Bluetooth-Low-Energy-in-Chinese/blob/master/chapter9.md)
    /// => [CBUUID(string: "0x180f") -> .batteryService (電池資料)](https://blog.csdn.net/chihuoyinshi/article/details/134726016)
    enum UUIDType: String {
        /* GATT服務 */
        case genericAccess = "0x1800"                                   // 通用訪問
        case alertNotificationService = "0x1811"                        // 鬧鐘通知
        case automationIO = "0x1815"                                    // 自動化輸入輸出
        case batteryService = "0x180F"                                  // 電池資料
        case binarySensor = "0x183B"                                    // 二元感測器
        case bloodPressure = "0x1810"                                   // 血壓
        case bodyComposition = "0x181B"                                 // 身體組成
        case bondManagementService = "0x181E"                           // 裝置繫結管理
        case continuousGlucoseMonitoring = "0x181F"                     // 動態血糖檢測
        case currentTimeService = "0x1805"                              // 當前時間
        case cyclingPower = "0x1818"                                    // 循環電量
        case cyclingSpeedAndCadence = "0x1816"                          // 循環速度、節奏
        case deviceInformation = "0x180A"                               // 裝置資訊
        case emergencyConfiguration = "0x183C"                          // 應急組態
        case environmentalSensing = "0x181A"                            // 環境感測
        case fitnessMachine = "0x1826"                                  // 健康裝置
        case genericAttribute = "0x1801"                                // 通用屬性
        case glucose = "0x1808"                                         // 葡萄糖
        case healthThermometer = "0x1809"                               // 溫度計
        case heartRate = "0x180D"                                       // 心率
        case httpProxy = "0x1823"                                       // HTTP代理
        case humanInterfaceDevice = "0x1812"                            // HID裝置
        case immediateAlert = "0x1802"                                  // 即時鬧鐘
        case indoorPositioning = "0x1821"                               // 室內定位
        case insulinDelivery = "0x183A"                                 // 胰島素給藥
        case internetProtocolSupportService = "0x1820"                  // 網際網路協議支援
        case linkLoss = "0x1803"                                        // 連接丟失
        case locationAndNavigation = "0x1819"                           // 定位及導航
        case meshProvisioningService = "0x1827"                         // 節點組態
        case meshProxyService = "0x1828"                                // 節點代理
        case nextDSTChangeService = "0x1807"                            // 下個日光節約時間（夏令時）更改
        case objectTransferService = "0x1825"                           // 對象傳輸
        case phoneAlertStatusService = "0x180E"                         // 手機報警狀態
        case pulseOximeterService = "0x1822"                            // 脈搏血氧計
        case reconnectionConfiguration = "0x1829"                       // 重連組態
        case referenceTimeUpdateService = "0x1806"                      // 參照時間更新
        case runningSpeedAndCadence = "0x1814"                          // 跑步速度、節奏
        case scanParameters = "0x1813"                                  // 掃描參數
        case transportDiscovery = "0x1824"                              // 傳輸發現
        case txPower = "0x1804"                                         // 傳送功率
        case userData = "0x181C"                                        // 使用者資料
        case weightScale = "0x181D"                                     // 體重計
        /* GATT特徵 */
        case aerobicHeartRateLowerLimit = "0x2A7E"                      // 有氧心律下限
        case aerobicHeartRateUpperLimit = "0x2A84"                      // 有氧心率上限
        case aerobicThreshold = "0x2A7F"                                // 有氧運動閾值
        case age = "0x2A80"                                             // 年齡
        case aggregate = "0x2A5A"                                       // 裝置聚合
        case alertCategoryID = "0x2A43"                                 // 報警類別ID
        case alertCategoryIDBitMask = "0x2A42"                          // 報警類別ID位掩碼
        case alertLevel = "0x2A06"                                      // 報警等級
        case alertNotificationControlPoint = "0x2A44"                   // 報警通知控制點
        case alertStatus = "0x2A3F"                                     // 報警狀態
        case altitude = "0x2AB3"                                        // 海拔
        case anaerobicHeartRateLowerLimit = "0x2A81"                    // 無氧心率下限
        case anaerobicHeartRateUpperLimit = "0x2A82"                    // 無氧心率上限
        case anaerobicThreshold = "0x2A83"                              // 無氧運動閾值
        case analog = "0x2A58"                                          // 模擬
        case analogOutput = "0x2A59"                                    // 模擬輸出
        case apparentWindDirection = "0x2A73"                           // 視風向
        case apparentWindSpeed = "0x2A72"                               // 視風速
        case appearance = "0x2A01"                                      // 外觀
        case barometricPressureTrend = "0x2AA3"                         // 氣壓趨勢
        case batteryLevel = "0x2A19"                                    // 電池電量
        case batteryLevelState = "0x2A1B"                               // 電池電量狀態
        case batteryPowerState = "0x2A1A"                               // 電池電量狀態
        case bloodPressureFeature = "0x2A49"                            // 血壓功能
        case bloodPressureMeasurement = "0x2A35"                        // 血壓測量
        case bodyCompositionFeature = "0x2A9B"                          // 身體組成特徵
        case bodyCompositionMeasurement = "0x2A9C"                      // 身體組成測量
        case bodySensorLocation = "0x2A38"                              // 人體感應器位置
        case bondManagementControlPoint = "0x2AA4"                      // 繫結管理控制點
        case bondManagementFeatures = "0x2AA5"                          // 繫結管理功能
        case bootKeyboardInputReport = "0x2A22"                         // 啟動鍵盤輸入報告
        case bootKeyboardOutputReport = "0x2A32"                        // 啟動鍵盤輸出報告
        case bootMouseInputReport = "0x2A33"                            // 啟動滑鼠輸入報告
        case bssControlPoint = "2B2B"                                   // BSS控制點
        case bssResponse = "2B2C"                                       // BSS回應
        case cgmFeature = "0x2AA8"                                      // CGM功能
        case cgmMeasurement = "0x2AA7"                                  // CGM測量
        case cgmSessionRunTime = "0x2AAB"                               // CGM會話執行階段間
        case cgmSessionStartTime = "0x2AAA"                             // CGM會話開始時間
        case cgmSpecificOpsControlPoint = "0x2AAC"                      // CGM特定操作控制點
        case cgmStatus = "0x2AA9"                                       // CGM狀態
        case crossTrainerData = "0x2ACE"                                // 交叉訓練員資料
        case cscFeature = "0x2A5C"                                      // CSC功能
        case cscMeasurement = "0x2A5B"                                  // CSC測量
        case currentTime = "0x2A2B"                                     // 當前時間
        case cyclingPowerControlPoint = "0x2A66"                        // 騎行能量控制點
        case cyclingPowerFeature = "0x2A65"                             // 騎行能量功能
        case cyclingPowerMeasurement = "0x2A63"                         // 騎行能量測量
        case cyclingPowerVector = "0x2A64"                              // 騎行能量向量
        case databaseChangeIncrement = "0x2A99"                         // 資料庫更改增量
        case dateofBirth = "0x2A85"                                     // 出生日期
        case dateofThresholdAssessment = "0x2A86"                       // 閾值評估日期
        case dateTime = "0x2A08"                                        // 日期時間
        case dateUTC = "0x2AED"                                         // UTC時間
        case dayDateTime = "0x2A0A"                                     // 日期時間天
        case dayofWeek = "0x2A09"                                       // 星期幾
        case descriptorValueChanged = "0x2A7D"                          // 描述符值已更改
        case dewPoint = "0x2A7B"                                        // 露點溫度
        case digital = "0x2A56"                                         // 數字
        case digitalOutput = "0x2A57"                                   // 數字輸出
        case dSTOffset = "0x2A0D"                                       // 日光節約時間（夏令時）偏移
        case elevation = "0x2A6C"                                       // 海拔
        case emailAddress = "0x2A87"                                    // 電子郵件地址
        case emergencyID = "2B2D"                                       // 突發事件ID
        case emergencyText = "2B2E"                                     // 突發事件內容
        case exactTime100 = "0x2A0B"                                    // 具體時間100
        case exactTime256 = "0x2A0C"                                    // 具體時間256
        case fatBurnHeartRateLowerLimit = "0x2A88"                      // 脂肪燃燒心率下限
        case fatBurnHeartRateUpperLimit = "0x2A89"                      // 脂肪燃燒心率上限
        case firmwareRevisionString = "0x2A26"                          // 韌體修訂字元
        case firstName = "0x2A8A"                                       // 名字
        case fitnessMachineControlPoint = "0x2AD9"                      // 健身裝置控制點
        case fitnessMachineFeature = "0x2ACC"                           // 健身裝置功能
        case fitnessMachineStatus = "0x2ADA"                            // 健身裝置狀態
        case fiveZoneHeartRateLimits = "0x2A8B"                         // 五區心率限制
        case floorNumber = "0x2AB2"                                     // 樓層號
        case centralAddressResolution = "0x2AA6"                        // 中央地址解析
        case deviceName = "0x2A00"                                      // 裝置名稱
        case peripheralPreferredConnectionParameters = "0x2A04"         // 外圍裝置首選連接參數
        case peripheralPrivacyFlag = "0x2A02"                           // 周邊隱私標誌
        case reconnectionAddress = "0x2A03"                             // 重新連接地址
        case serviceChanged = "0x2A05"                                  // 服務已更改
        case gender = "0x2A8C"                                          // 性別
        case glucoseFeature = "0x2A51"                                  // 葡萄糖功能
        case glucoseMeasurement = "0x2A18"                              // 血糖測量
        case glucoseMeasurementContext = "0x2A34"                       // 葡萄糖測量環境
        case gustFactor = "0x2A74"                                      // 陣風係數
        case hardwareRevisionString = "0x2A27"                          // 硬體修訂字元
        case heartRateControlPoint = "0x2A39"                           // 心率控制點
        case heartRateMax = "0x2A8D"                                    // 最大心率
        case heartRateMeasurement = "0x2A37"                            // 心率測量
        case heatIndex = "0x2A7A"                                       // 熱度指數
        case height = "0x2A8E"                                          // 高度
        case hidControlPoint = "0x2A4C"                                 // HID控制點
        case hidInformation = "0x2A4A"                                  // HID資訊
        case hipCircumference = "0x2A8F"                                // 臀圍
        case httpControlPoint = "0x2ABA"                                // HTTP控制點
        case httpEntityBody = "0x2AB9"                                  // HTTP實體主體
        case httpHeaders = "0x2AB7"                                     // HTTP頭
        case httpStatusCode = "0x2AB8"                                  // HTTP狀態碼
        case httpSSecurity = "0x2ABB"                                   // HTTPS安全性
        case humidity = "0x2A6F"                                        // 濕度
        case iddAnnunciationStatus = "2B22"                             // IDD通告狀態
        case iddCommandControlPoint = "2B25"                            // IDD命令控制點
        case iddCommandData = "2B26"                                    // IDD命令資料
        case iddFeatures = "2B23"                                       // IDD功能
        case iddHistoryData = "2B28"                                    // IDD歷史資料
        case iddRecordAccessControlPoint = "2B27"                       // IDD記錄存取控制點
        case iddStatus = "2B21"                                         // IDD狀態
        case iddStatusChanged = "2B20"                                  // IDD狀態已更改
        case iddStatusReaderControlPoint = "2B24"                       // IDD狀態讀取器控制點
        case ieee1073_20601RegulatoryCertificationDataList = "0x2A2A"   // IEEE11073-20601法規認證資料列表
        case indoorBikeData = "0x2AD2"                                  // 室內自行車資料
        case indoorPositioningConfiguration = "0x2AAD"                  // 室內定位組態
        case intermediateCuffPressure = "0x2A36"                        // 中間的氣囊壓力
        case intermediateTemperature = "0x2A1E"                         // 中間的溫度
        case irradiance = "0x2A77"                                      // 輻照度
        case language = "0x2AA2"                                        // 語言
        case lastName = "0x2A90"                                        // 姓
        case latitude = "0x2AAE"                                        // 緯度
        case lNControlPoint = "0x2A6B"                                  // LN控制點
        case lNFeature = "0x2A6A"                                       // LN功能
        case localEastCoordinate = "0x2AB1"                             // 當地東部坐標
        case localNorthCoordinate = "0x2AB0"                            // 當地北部坐標
        case localTimeInformation = "0x2A0F"                            // 當地時間資訊
        case locationandSpeedCharacteristic = "0x2A67"                  // 位置和速度特徵
        case locationName = "0x2AB5"                                    // 地點名稱
        case longitude = "0x2AAF"                                       // 經度
        case magneticDeclination = "0x2A2C"                             // 磁偏角
        case magneticFluxDensity2D = "0x2AA0"                           // 磁通密度–2D
        case magneticFluxDensity3D = "0x2AA1"                           // 磁通密度–3D
        case manufacturerNameString = "0x2A29"                          // 製造商名稱字元
        case maximumRecommendedHeartRate = "0x2A91"                     // 推薦最大心率
        case measurementInterval = "0x2A21"                             // 測量間隔
        case modelNumberString = "0x2A24"                               // 型號字元
        case navigation = "0x2A68"                                      // 導航
        case networkAvailability = "0x2A3E"                             // 網路可用性
        case newAlert = "0x2A46"                                        // 新警報
        case objectActionControlPoint = "0x2AC5"                        // 對象動作控制點
        case objectChanged = "0x2AC8"                                   // 對像已更改
        case objectFirstCreated = "0x2AC1"                              // 對象首先建立
        case objectID = "0x2AC3"                                        // 對象ID
        case objectLastModified = "0x2AC2"                              // 上次修改的對象
        case objectListControlPoint = "0x2AC6"                          // 對象列表控制點
        case objectListFilter = "0x2AC7"                                // 對象列表過濾器
        case objectName = "0x2ABE"                                      // 對象名稱
        case objectProperties = "0x2AC4"                                // 對象屬性
        case objectSize = "0x2AC0"                                      // 對象大小
        case objectType = "0x2ABF"                                      // 對象類型
        case otsFeature = "0x2ABD"                                      // OTS功能
        case plxContinuousMeasurementCharacteristic = "0x2A5F"          // PLX連續測量特性
        case plxFeatures = "0x2A60"                                     // PLX功能
        case plxSpotCheckMeasurement = "0x2A5E"                         // PLX抽查檢查
        case pnPID = "0x2A50"                                           // 即插即用ID
        case pollenConcentration = "0x2A75"                             // 花粉濃度
        case position2D = "0x2A2F"                                      // 位置2D
        case position3D = "0x2A30"                                      // 位置3D
        case positionQuality = "0x2A69"                                 // 位置質量
        case pressure = "0x2A6D"                                        // 壓力
        case protocolMode = "0x2A4E"                                    // 協議模式
        case pulseOximetryControlPoint = "0x2A62"                       // 脈搏血氧飽和度控制點
        case rainfall = "0x2A78"                                        // 雨量
        case rCFeature = "2B1D"                                         // RC功能
        case rCSettings = "2B1E"                                        // RC設定
        case reconnectionConfigurationControlPoint = "2B1F"             // 重新連接組態控制點
        case recordAccessControlPoint = "0x2A52"                        // 記錄存取控制點
        case referenceTimeInformation = "0x2A14"                        // 參考時間資訊
        case registeredUserCharacteristic = "2B37"                      // 註冊使用者特徵
        case removable = "0x2A3A"                                       // 可移動的
        case report = "0x2A4D"                                          // 報告
        case reportMap = "0x2A4B"                                       // 報告地圖
        case resolvablePrivateAddressOnly = "0x2AC9"                    // 僅可解析的私有地址
        case restingHeartRate = "0x2A92"                                // 靜息心率
        case ringerControlpoint = "0x2A40"                              // 鈴聲控制點
        case ringerSetting = "0x2A41"                                   // 鈴聲設定
        case rowerData = "0x2AD1"                                       // 槳手資料
        case rscFeature = "0x2A54"                                      // RSC功能
        case rscMeasurement = "0x2A53"                                  // RSC測量
        case scControlPoint = "0x2A55"                                  // SC控制點
        case scanIntervalWindow = "0x2A4F"                              // 掃描間隔窗口
        case scanRefresh = "0x2A31"                                     // 掃描刷新
        case scientificTemperatureCelsius = "0x2A3C"                    // 科學溫度（攝氏度）
        case secondaryTimeZone = "0x2A10"                               // 次要時區
        case sensorLocation = "0x2A5D"                                  // 感測器位置
        case serialNumberString = "0x2A25"                              // 序列號字元
        case serviceRequired = "0x2A3B"                                 // 所需服務
        case softwareRevisionString = "0x2A28"                          // 軟體修訂版字元
        case sportTypeforAerobicandAnaerobicThresholds = "0x2A93"       // 有氧閾值和無氧閾值的運動類型
        case stairClimberData = "0x2AD0"                                // 攀登樓梯數
        case stepClimberData = "0x2ACF"                                 // 攀登者步數
        case string = "0x2A3D"                                          // 字串
        case supportedHeartRateRange = "0x2AD7"                         // 支援的心率範圍
        case supportedInclinationRange = "0x2AD5"                       // 支援的傾斜範圍
        case supportedNewAlertCategory = "0x2A47"                       // 支援的新警報類別
        case supportedPowerRange = "0x2AD8"                             // 支援的功率範圍
        case supportedResistanceLevelRange = "0x2AD6"                   // 支援的電阻水平範圍
        case supportedSpeedRange = "0x2AD4"                             // 支援的速度範圍
        case supportedUnreadAlertCategory = "0x2A48"                    // 支援的未讀警報類別
        case systemID = "0x2A23"                                        // 系統編號
        case tDSControlPoint = "0x2ABC"                                 // TDS控制點
        case temperature = "0x2A6E"                                     // 溫度
        case temperatureCelsius = "0x2A1F"                              // 溫度攝氏
        case temperatureFahrenheit = "0x2A20"                           // 溫度華氏度
        case temperatureMeasurement = "0x2A1C"                          // 溫度測量
        case temperatureType = "0x2A1D"                                 // 溫度類型
        case threeZoneHeartRateLimits = "0x2A94"                        // 三區心率限制
        case timeAccuracy = "0x2A12"                                    // 時間精度
        case timeBroadcast = "0x2A15"                                   // 時間廣播
        case timeSource = "0x2A13"                                      // 時間來源
        case timeUpdateControlPoint = "0x2A16"                          // 時間更新控制點
        case timeUpdateState = "0x2A17"                                 // 時間更新狀態
        case timewithDST = "0x2A11"                                     // 夏令時
        case timeZone = "0x2A0E"                                        // 時區
        case trainingStatus = "0x2AD3"                                  // 訓練狀況
        case treadmillData = "0x2ACD"                                   // 跑步機資料
        case trueWindDirection = "0x2A71"                               // 真風向
        case trueWindSpeed = "0x2A70"                                   // 真風速
        case twoZoneHeartRateLimit = "0x2A95"                           // 兩區心率限制
        case txPowerLevel = "0x2A07"                                    // 發射功率等級
        case uncertainty = "0x2AB4"                                     // 不確定
        case unreadAlertStatus = "0x2A45"                               // 未讀警報狀態
        case uri = "0x2AB6"                                             // URI連結
        case userControlPoint = "0x2A9F"                                // 使用者控制點
        case userIndex = "0x2A9A"                                       // 使用者索引
        case uvIndex = "0x2A76"                                         // 紫外線指數
        case v02Max = "0x2A96"                                          // 最大攝氧量
        case waistCircumference = "0x2A97"                              // 腰圍
        case weight = "0x2A98"                                          // 重量
        case weightMeasurement = "0x2A9D"                               // 體重測量
        case weightScaleFeature = "0x2A9E"                              // 體重秤功能
        case windChill = "0x2A79"                                       // 風寒（係數吧）
        /* GATT描述符 */
        case characteristicAggregateFormat = "0x2905"                   // 特徵彙總格式
        case characteristicExtendedProperties = "0x2900"                // 特性擴展屬性
        case characteristicPresentationFormat = "0x2904"                // 特徵描述格式
        case characteristicUserDescription = "0x2901"                   // 特徵使用者描述
        case clientCharacteristicConfiguration = "0x2902"               // 客戶端特徵組態
        case environmentalSensingConfiguration = "0x290B"               // 環境感應組態
        case environmentalSensingMeasurement = "0x290C"                 // 環境感測
        case environmentalSensingTriggerSetting = "0x290D"              // 環境感應觸發設定
        case externalReportReference = "0x2907"                         // 外部報告參考
        case numberofDigitals = "0x2909"                                // 數字個數
        case reportReference = "0x2908"                                 // 報告參考
        case serverCharacteristicConfiguration = "0x2903"               // 伺服器特徵組態
        case timeTriggerSetting = "0x290E"                              // 時間觸發設定
        case validRange = "0x2906"                                      // 有效範圍
        case valueTriggerSetting = "0x290A"                             // 數值觸發設定
        /* GATT聲明 */
        case characteristicDeclaration = "0x2803"                       // 特徵聲明
        case include = "0x2802"                                         // 包括
        case primaryService = "0x2800"                                  // 主要服務
        case secondaryService = "0x2801"                                // 次要服務
        /* 自定義 */
        case continuity = "D0611E78-BBB4-4591-A5F8-487910AE4366"        // 接續互通
        case bluMidi = "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"           // 藍芽Midi
        case read = "0000FF10-0000-1000-8000-00805F9B34FB"              // 讀取
        case write = "B7860002-11B8-B681-6343-5A6C2286633F"             // 寫入
        case notify = "B7860003-11B8-B681-6343-5A6C2286633F"            // 通知
    }
}

// MARK: - UUID類型
public extension WWBluetoothManager.UUIDType {
    
    /// 尋找UUIDType
    /// - Parameter uuidString: String
    /// - Returns: UUIDType?
    static func find(uuidString: String) -> Self? {
        return Self(rawValue: uuidString)
    }
    
    /// 尋找UUIDType
    /// - Parameter uuid: CBUUID
    /// - Returns: UUIDType?
    static func find(uuid: CBUUID) -> Self? {
        return Self.find(uuidString: uuid.uuidString)
    }
}

// MARK: - UUID類型 (GATT)
public extension WWBluetoothManager.UUIDType {
        
    /// [UUID數值](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf)
    /// - Returns: [CBUUID](https://blog.csdn.net/hjj801006/article/details/135593595)
    func cbuuid() -> CBUUID { return CBUUID(string: self.rawValue) }
}

// MARK: - FileTransferError
extension WWBluetoothManager.FileTransferError: LocalizedError {
    
    /// 自訂錯誤訊息
    public var errorDescription: String? {
        
        switch self {
        case .writeFailed(let message): return "Write failed: \(message)"
        case .updateFailed(let message): return "Value update failed: \(message)"
        case .invalidRecord: return "Invalid transfer record"
        case .missingChunks: return "Missing chunks"
        case .peerReturnedError: return "Peer returned error"
        case .invalidTransferId: return "Invalid transfer ID"
        case .invalidPhase: return "Invalid transfer phase"
        case .missingCharacteristic: return "Missing characteristic"
        }
    }
}

// MARK: - AdvertisementDataKey
extension WWBluetoothManager {
    
    /// 廣告資料鍵值常數（CoreBluetooth 標準）
    enum AdvertisementDataKey: String {
        
        case localName = "CBAdvertisementDataLocalNameKey"                      // 設備本地名稱（廣告包中最優先的名稱來源）
        case manufacturerData = "CBAdvertisementDataManufacturerDataKey"        // 設備本地名稱（廣告包中最優先的名稱來源）
        case serviceUUIDs = "CBAdvertisementDataServiceUUIDsKey"                // 廣告中宣告的服務 UUID 列表（設備支援的 GATT 服務）
        case isConnectable = "CBAdvertisementDataIsConnectable"                 // 可連線標記（iOS 11+，指示設備是否接受連線）
    }
}

// MARK: - Event 轉換成文字
extension WWBluetoothManager.ClientEvent: @retroactive CustomStringConvertible {
    
    public var description: String {
        
        switch self {
        case .stateChanged(let state): return "State: \(state.rawValue)"
        case .discovered(let device): return "Discovered: \(device.name) (RSSI: \(device.rssi))"
        case .connected: return "Connected ✅"
        case .disconnected(let device, let error): return "Disconnected: \(device?.name ?? "Unknown") \(error.map { "\($0)" } ?? "")"
        case .servicesDiscovered(_, let services): return "Services: \(services.map { $0.uuidString })"
        case .characteristicsDiscovered(let service, let chars): return "Chars \(service.uuidString): \(chars.map { $0.uuidString })"
        case .notificationEnabled(let uuid): return "Notify ON: \(uuid.uuidString)"
        case .valueUpdated(let uuid, let data): return "Notify \(uuid.uuidString): \(data.map { String(format: "%02x", $0) }.joined())"
        case .writeCompleted(let uuid, let error): return "Write \(uuid.uuidString): \(error.map { "\($0)" } ?? "OK")"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}
