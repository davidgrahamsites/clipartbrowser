# Project Context

## User Request
Create a Mac M1 app that can:
- Import documents with lists of vocabulary words.
- Distinguish vocabulary words from ordinary body text by detecting sections like "Vocabulary", "Vocabulary Words", "Key Words", "Word Bank", or similar headings.
- Preserve the order vocabulary words appear in.
- Search online for clipart images for each vocabulary word.
- Trim image white padding.
- Create portrait letter flashcards.
- Size images as large as possible while leaving about 12 px of padding by default.
- Make padding adjustable with a slider or numeric input.
- Continue processing all words automatically.
- Show all flashcards for review before exporting.
- Export a PowerPoint `.pptx`.
- Compile to a `.app`.
- Run everything inside the `.app`.

## Important Product Detail
Google Images is not the default provider because it does not offer a simple no-key public image search API. Direct scraping is fragile and often blocked. The first version should use no-key sources such as Openverse and Wikimedia Commons, while keeping image search provider-based so Google Custom Search can be added later if the user provides an API key and search engine ID.

## Current Workspace
Path: `/Users/appleadmin/Apps/ClipartBrowser`

The repository started empty and is not currently a git repository.

