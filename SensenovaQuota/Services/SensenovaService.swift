import Foundation

struct SensenovaService {
    static let baseURL = "https://token.sensenova.cn"
    static let platformURL = "https://platform.sensenova.cn"
    
    /// 检测单个 API Key 的有效性
    /// - Returns: (状态, 错误描述)
    static func checkKey(_ key: String) async -> (AccountStatus, String?) {
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            return (.error, "URL 格式错误")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (.error, "无法解析响应")
            }
            
            switch httpResponse.statusCode {
            case 200:
                return (.active, nil)
            case 401:
                return (.inactive, "API Key 无效或已过期 (401)")
            case 429:
                return (.inactive, "请求频率超限 (429)")
            case 403:
                return (.inactive, "无权限 (403)")
            default:
                return (.error, "HTTP \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return (.error, "请求超时")
            case .notConnectedToInternet:
                return (.error, "无网络连接")
            case .cannotFindHost, .cannotConnectToHost:
                return (.error, "无法连接到服务器")
            default:
                return (.error, "网络错误: \(error.localizedDescription)")
            }
        } catch {
            return (.error, error.localizedDescription)
        }
    }
    
    /// 批量检测，返回结果字典 [索引: 状态]
    static func checkAllKeys(_ keys: [(index: Int, key: String)]) async -> [Int: (AccountStatus, String?)] {
        return await withTaskGroup(of: (Int, AccountStatus, String?).self) { group in
            for (index, key) in keys {
                group.addTask {
                    let (status, error) = await checkKey(key)
                    return (index, status, error)
                }
            }
            
            var results: [Int: (AccountStatus, String?)] = [:]
            for await (index, status, error) in group {
                results[index] = (status, error)
            }
            return results
        }
    }
}