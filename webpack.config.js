// The builder exposes the extension by absolute path, and webpack's default
// module ids hash it, so builds in different directories would differ.
module.exports = {
  optimization: { moduleIds: 'natural' }
};
