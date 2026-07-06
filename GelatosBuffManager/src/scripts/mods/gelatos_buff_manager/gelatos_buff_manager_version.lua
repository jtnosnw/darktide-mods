-- Single source of truth for the mod's version number.
--
-- SemVer (MAJOR.MINOR.PATCH):
--   MAJOR -- breaking save-data or settings changes that require user action
--   MINOR -- new features, backward compatible
--   PATCH -- bug fixes only, backward compatible
--
-- Bump this string (and only this string) on every release; everywhere else
-- reads it from here. First public-ready build should be tagged "1.0.0".
return "0.23.4"
