// ════════════════════════════════════════════════════════════════════════════════
// CheddaBoards Files Module
// File upload, storage, and retrieval functionality
// ════════════════════════════════════════════════════════════════════════════════

import List "mo:base/List";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

module {

  // ════════════════════════════════════════════════════════════════════════════
  // TYPES
  // ════════════════════════════════════════════════════════════════════════════

  public type FileList = List.List<(Text, Blob)>;
  
  public type FileInfo = {
    name : Text;
    size : Nat;
  };

  public type UploadResult = {
    files : FileList;
    result : Result.Result<Text, Text>;
  };

  public type DeleteResult = {
    files : FileList;
    result : Result.Result<Text, Text>;
  };

  // ════════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ════════════════════════════════════════════════════════════════════════════

  public let MAX_FILE_SIZE : Nat = 5_000_000;  // 5MB
  public let MAX_FILES : Nat = 100;

  // ════════════════════════════════════════════════════════════════════════════
  // FUNCTIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Upload or update a file
  /// Returns the new file list and the result
  public func upload(
    files : FileList,
    filename : Text,
    data : Blob
  ) : UploadResult {
    // Check file size
    if (Blob.toArray(data).size() > MAX_FILE_SIZE) {
      return {
        files = files;
        result = #err("File too large. Max size: 5MB");
      };
    };

    // Check file count limit
    if (List.size(files) >= MAX_FILES) {
      return {
        files = files;
        result = #err("File limit reached. Max files: " # Nat.toText(MAX_FILES));
      };
    };

    // Check if file exists (update) or is new (insert)
    var found = false;
    let newFiles = List.map<(Text, Blob), (Text, Blob)>(
      files,
      func(f : (Text, Blob)) : (Text, Blob) {
        if (f.0 == filename) {
          found := true;
          (filename, data)
        } else {
          f
        }
      }
    );

    if (found) {
      {
        files = newFiles;
        result = #ok("File updated: " # filename);
      }
    } else {
      {
        files = List.push((filename, data), files);
        result = #ok("File uploaded: " # filename);
      }
    }
  };

  /// Delete a file by filename
  /// Returns the new file list and the result
  public func delete(files : FileList, filename : Text) : DeleteResult {
    let newFiles = List.filter<(Text, Blob)>(
      files,
      func(f : (Text, Blob)) : Bool { f.0 != filename }
    );

    if (List.size(newFiles) == List.size(files)) {
      {
        files = files;
        result = #err("File not found: " # filename);
      }
    } else {
      {
        files = newFiles;
        result = #ok("File deleted: " # filename);
      }
    }
  };

  /// List all filenames
  public func list(files : FileList) : [Text] {
    List.toArray(
      List.map<(Text, Blob), Text>(
        files,
        func(tup : (Text, Blob)) : Text { tup.0 }
      )
    )
  };

  /// Get a file's content by filename
  public func get(files : FileList, filename : Text) : ?Blob {
    let found = List.find<(Text, Blob)>(
      files,
      func(tup : (Text, Blob)) : Bool { tup.0 == filename }
    );
    switch (found) {
      case null null;
      case (?(_, blob)) ?blob;
    }
  };

  /// Get file info (name and size) by filename
  public func getInfo(files : FileList, filename : Text) : ?FileInfo {
    let found = List.find<(Text, Blob)>(
      files,
      func(tup : (Text, Blob)) : Bool { tup.0 == filename }
    );
    switch (found) {
      case null null;
      case (?(name, blob)) ?{ name = name; size = Blob.toArray(blob).size() };
    }
  };

  /// Get total count of files
  public func count(files : FileList) : Nat {
    List.size(files)
  };

  /// Get total storage used (in bytes)
  public func totalSize(files : FileList) : Nat {
    List.foldLeft<(Text, Blob), Nat>(
      files,
      0,
      func(acc : Nat, f : (Text, Blob)) : Nat {
        acc + Blob.toArray(f.1).size()
      }
    )
  };

}
