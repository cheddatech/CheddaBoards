// One-shot upgrade migration for the Files module removal.
//
// EOP will not implicitly discard a stable field, so this consumes
// `stableFiles` from the previous version and produces nothing in its
// place. Every other stable field is carried over untouched.
//
// Delete this file and the `(with migration = Migration.run)` clause in
// main.mo once the upgrade has been applied to every canister.
module {
  public func run(old : { stableFiles : [(Text, Blob)] }) : {} {
    ignore old;
    {}
  };
};
