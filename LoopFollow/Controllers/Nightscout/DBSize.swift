// LoopFollow
// DBSize.swift

import Foundation

/// Response shape of `/api/v2/properties/dbsize`.
///
/// Nightscout's `dbsize` plugin reports the Mongo `dataSize + indexSize` sum
/// against `DBSIZE_MAX` (defaults to 496 MiB when the site admin has not set it).
/// The key is absent when the plugin has not produced a property yet.
struct DBSizeProperties: Codable {
    let dbsize: DBSizeData?
}

struct DBSizeData: Codable {
    /// Used size, in MiB.
    let totalDataSize: Double?
    /// Used size as a percentage of `details.maxSize`, floored by the server.
    let dataPercentage: Int?
    let details: Details?

    struct Details: Codable {
        /// The configured limit in MiB (`DBSIZE_MAX`).
        let maxSize: Double?
        let dataSize: Double?
    }
}

extension MainViewController {
    // NS Database Size Web Call
    func webLoadNSDBSize() {
        NightscoutUtils.executeRequest(eventType: .dbSize, parameters: [:]) { (result: Result<DBSizeProperties, Error>) in
            switch result {
            case let .success(properties):
                self.updateDBSize(data: properties.dbsize)
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "webLoadNSDBSize, error: \(error.localizedDescription)")
            }
        }
    }

    // NS Database Size Response Processor
    func updateDBSize(data: DBSizeData?) {
        // Nightscout still reports the property when `db.stats()` failed, but with a zero
        // size. Its own pill hides on that, so treat it as "no reading" rather than 0%.
        guard let data = data, let usedMiB = data.totalDataSize, usedMiB > 0 else {
            infoManager.clearInfoData(type: .dbSize)
            Observable.shared.dbSizePercentage.set(nil)
            return
        }

        Observable.shared.dbSizePercentage.set(data.dataPercentage.map(Double.init))

        let used = Localizer.formatToLocalizedString(usedMiB, maxFractionDigits: 0, minFractionDigits: 0)

        if let percentage = data.dataPercentage {
            infoManager.updateInfoData(type: .dbSize, value: "\(used) MiB (\(percentage)%)")
        } else {
            infoManager.updateInfoData(type: .dbSize, value: "\(used) MiB")
        }
    }
}
