//
//  MemberFetcher.swift
//  MyRep
//
//  Created by Rhett Rogers on 6/5/20.
//  Copyright © 2020 Rhett Rogers. All rights reserved.
//

import Foundation
import Combine


class MemberFetcher: NSObject {
    
    typealias MemberResult = Future<[Member], Never>
    
    static let shared = MemberFetcher()
    
    enum APIEndpoint: String, CaseIterable {
        case name = "Name"
        case zip = "ZIP"
        case state = "State"
    }
    
    
    static let baseComponents: URLComponents = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "whoismyrepresentative.com"
        components.queryItems = [
            URLQueryItem(name: "output", value: "json")
        ]
        return components
    }()
    
    var subscriptions = Set<AnyCancellable>()
    
    func publisher(for url: URL) -> AnyPublisher<[Member], Never> {
        URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
            .dataTaskPublisher(for: url)
            .map { data, _ -> RootMember in
                do {
                    return try JSONDecoder().decode(RootMember.self, from: data)
                } catch {
                    print(error.localizedDescription)
                    print(String(data: data, encoding: .utf8) ?? "")
                    
                    return RootMember(results: [])
                }
            }
            .map(\.results)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
    
    func getAllMembers(byZip zip: String) -> MemberResult {
        return Future { fulfill in
            var components = MemberFetcher.baseComponents
            components.path = "/getall_mems.php"
            components.queryItems?.append(URLQueryItem(name: "zip", value: zip))
            self.publisher(for: components.url!)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print(error.localizedDescription)
                        fulfill(.success([]))
                    default: return
                    }
                }) { members in
                    fulfill(.success(members))
            }
            .store(in: &self.subscriptions)
        }
        
    }
    
    func getAllMembers(byName name: String) -> MemberResult {
        MemberResult { fulfill in

            var components = MemberFetcher.baseComponents
            components.queryItems?.append(URLQueryItem(name: "name", value: name))
            
            components.path = "/getall_reps_byname.php"
            let repsPublisher = self.publisher(for: components.url!)
            
            components.path = "/getall_sens_byname.php"
            let senatorsPublisher = self.publisher(for: components.url!)
            
            repsPublisher
                .merge(with: senatorsPublisher)
                .reduce([], { current, next in
                    var current = current
                    current.append(contentsOf: next)
                    return current
                })
                .sink { members in
                    fulfill(.success(members))
            }
            .store(in: &self.subscriptions)

        }
        
        
    }
    
    func getAllMembers(byState state: String) -> MemberResult {
        MemberResult { fulfill in

            var components = MemberFetcher.baseComponents
            components.queryItems?.append(URLQueryItem(name: "state", value: state))
            
            components.path = "/getall_reps_bystate.php"
            let repsPublisher = self.publisher(for: components.url!)
            
            components.path = "/getall_sens_bystate.php"
            let senatorsPublisher = self.publisher(for: components.url!)
            
            repsPublisher
                .merge(with: senatorsPublisher)
                .reduce([], { current, next in
                    var current = current
                    current.append(contentsOf: next)
                    return current
                })
                .sink { members in
                    fulfill(.success(members))
            }
            .store(in: &self.subscriptions)

        }
    }

    
}

extension MemberFetcher: URLSessionDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
        }
        return completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
    }
    
}
