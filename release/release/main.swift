#!/usr/bin/swift

//
//  main.swift
//  r.swift.release
//
//  Created by Tomas Harkema on 12-02-16.
//  Copyright © 2016 Tomas Harkema Media. All rights reserved.
//

import Foundation

let Brew = "/usr/local/bin/brew"
let Git = "/usr/bin/git"

enum TaskResult {
  case Success([String])
  case Error(String)

  var result: [String]? {
    switch self {
    case .Success(let lines):
      return lines

    default:
      return nil
    }
  }
}

func runTask(command: String, args: [String]) -> TaskResult {
  let task = NSTask()
  task.launchPath = command
  task.arguments = args

  let outputPipe = NSPipe()
  task.standardOutput = outputPipe

  let errorPipe = NSPipe()
  task.standardError = errorPipe

  let outputPipeFile = outputPipe.fileHandleForReading
  let errorPipeFile = errorPipe.fileHandleForReading

  task.launch()

  let outputData = outputPipeFile.readDataToEndOfFile()
  let errorData = errorPipeFile.readDataToEndOfFile()

  if let standardOut = String(data: outputData, encoding: NSUTF8StringEncoding) {
    return .Success(standardOut.componentsSeparatedByString("\n"))
  }

  return .Error(String(data: errorData, encoding: NSUTF8StringEncoding) ?? "could not determine error")
}

func getJson(url: NSURL) -> AnyObject? {
  guard let jsonData = NSData(contentsOfURL: url) else {
    return nil
  }

  guard let json = try? NSJSONSerialization.JSONObjectWithData(jsonData, options: []) else {
    return nil
  }

  return json
}

func rswiftLatestReleaseTag() -> String? {

  guard let releaseJson = getJson(NSURL(string: "https://api.github.com/repos/mac-cain13/R.swift/releases")!) as? [AnyObject] else {
    return nil
  }

  guard let tag = releaseJson.first?["tag_name"] as? String else {
    return nil
  }

  return tag
}

func rswiftLatestReleaseCommitSha(tag: String) -> String? {
  guard let commitHash = runTask(Git, args: ["rev-parse", tag]).result?.first else {
    return nil
  }

  return commitHash
}

// make brew up-to-date

let brewUpdate = runTask(Brew, args: ["update"]).result?.joinWithSeparator("\n") ?? "Could not update brew"

print("Update brew", brewUpdate)

// get repository path

guard let brewRepoPath = runTask(Brew, args: ["--repository"]).result?.first else {
  print("Should've gained a brewRepoPath")
  exit(1)
}

print(brewRepoPath)

guard let rswiftFormulaPath = runTask("/usr/bin/find", args: [brewRepoPath, "-name", "rswift.rb"]).result?.first where rswiftFormulaPath.lowercaseString.rangeOfString("rswift.rb") != nil else {
  print("Should've gained a path to rswift.rb")
  exit(1)
}

print(rswiftFormulaPath)

guard let rswiftFormulaContents = try? String(contentsOfFile: rswiftFormulaPath, encoding: NSUTF8StringEncoding) else {
  print("Should've gained a path to rswift.rb")
  exit(1)
}

print(rswiftFormulaContents)

guard let rswiftLatestReleaseTag = rswiftLatestReleaseTag() else {
  print("Should've gained a path to rswift.rb")
  exit(1)
}

print(rswiftLatestReleaseTag)

guard let rswiftLatestReleaseSha = rswiftLatestReleaseCommitSha(rswiftLatestReleaseTag) else {
  print("Should've gained a path to rswift.rb")
  exit(1)
}

print(rswiftLatestReleaseSha)

let tagRegex = (try? NSRegularExpression(pattern: ":tag => \"(.*)\"", options: .CaseInsensitive))!

let rswiftFormulaContentsWithTag = tagRegex.stringByReplacingMatchesInString(
  rswiftFormulaContents,
  options: [],
  range: NSMakeRange(0, rswiftFormulaContents.characters.count),
  withTemplate: ":tag => \"\(rswiftLatestReleaseTag)\"")

let revisionRegex = (try? NSRegularExpression(pattern: ":revision => \"(.*)\"", options: .CaseInsensitive))!

let rswiftFormulaContentsWithTagAndRange = revisionRegex.stringByReplacingMatchesInString(rswiftFormulaContentsWithTag, options: [], range: NSMakeRange(0, rswiftFormulaContents.characters.count), withTemplate: ":revision => \"\(rswiftLatestReleaseSha)\"")

print(rswiftFormulaContentsWithTagAndRange)

do {
  try rswiftFormulaContentsWithTagAndRange
    .writeToFile(rswiftFormulaPath, atomically: true, encoding: NSUTF8StringEncoding)
} catch {
  print(error)
}

print("-- Updated \(rswiftFormulaPath)")

switch runTask(Brew, args: ["audit", "rswift"]) {
case let .Success(auditSuccess):
  print(auditSuccess)
case let .Error(error):
  print(error)
}
