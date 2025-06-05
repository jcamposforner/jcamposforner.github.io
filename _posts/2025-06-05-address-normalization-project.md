---
title: "Building an Address Normalization"
description: "Building Production-Ready Address Normalization: Lessons from Processing 50M+ Addresses"
categories: [ Geospatial, Address Normalization, Geocoder ]
tags: [ Geospatial, Address Normalization, Geocoder ]
hidden: true
---

Address normalization is one of those problems that seems simple until you hit the edge cases.

Addresses are
particularly challenging and inconsistent abbreviations, optional components, and no standardized format. Here's how I
built
a graph-based normalizer that handles real-world address data.

## Why Traditional Approaches Failed

The regex approach crashes on complexity and performance penalty.

Addresses mix abbreviations (**"C/", "Avda.", "Pl."**), optional components (**house numbers, door letters**), and
variable ordering.

A regex that handles **"C/ Mayor 23"** breaks on **"Avenida de la Constitución s/n esquina con Calle Real"**.

**Machine learning models** would likely be **too slow** for real-time processing and require constant retraining when
new address formats appear. Plus, they're overkill for what is fundamentally a structured parsing problem.

What actually worked was a **graph-based tokenizer** with fuzzy matching, fast enough for production and flexible enough
to handle addresses.

## Architecture Overview

### 1. Smart Tokenization with Graph Relationships

Instead of treating addresses as strings, we build a **connected graph** of relationships between tokens.

[IMAGE: Architecture diagram showing tokenization flow: Input String → Section Splitter → Word Tokenizer → Phrase Generator → Relationship Graph]

The tokenizer creates three levels:

- **Sections**: Split by commas and known delimiters
- **Words**: Individual tokens within sections
- **Phrases**: Words permutations (max 5 words)

The graph connections:

```kotlin
enum class Relationship {
  PREVIOUS,      // Links to previous word in sequence
  NEXT,          // Links to next word in sequence
  CHILD,         // Phrase points to its component words
  CHILD_LAST,    // Phrase points to its last word
  PARENT_FIRST,  // First word points to parent phrase
  PARENT,        // Any word points to parent phrase
  EQUIVALENT,    // Single-word phrases link to their word
}
```

[IMAGE: Graph visualization]

This connected structure helps disambiguate tokens.

For example, **"España"** could be part of "**Calle de España (street name), España (country)**".

The graph relationships help the classifier make better decisions.

### 2. Phrase Generation with Sliding Windows

The phrase generator creates all possible combinations up to 5 words using a sliding window approach:

[IMAGE: Diagram showing how an address generates phrases: "Avenida", "de", "América", "Avenida de", "de América", "Avenida de América" with their relationships]

Key design decisions:

- **EQUIVALENT** relationships for single-word phrases reduce redundancy
- **PARENT_FIRST** enables quick phrase boundary detection
- **CHILD_LAST** helps identify phrase ends without traversing all children

### 3. Classification Engine with Priority Queue

The classifiers run in a specific order because some depend on others for accurate scoring. Each classifier returns a
confidence score from **0.0** to **1.0**.

1. **RoadTypeClassifier**: Identifies **"Calle", "Avenida", "Plaza", "Carretera"** with **fuzzy matching**
2. **CountryClassifier**: Trie-based fuzzy search
3. **CityClassifier**: Trie-based fuzzy search
4. **StopWordClassifier**: Filters noise like **"de"**, **"la"**, **"con"**
5. **ZipcodeClassifier**: Composable pattern matching for countries
6. **HouseNumberClassifier**: Composable conditional between countries because regex was too slow. Handles "23", "
   23-25", "s/n", "23B"
7. **EuropeanStreetNameClassifier**: Uses abbreviation expansion (**"C/" → "Calle", "Avda" → "Avenida"**)

[IMAGE: Diagram showing classification pipeline]

The ordering is **critical** to ensure that tokens identified with high confidence by early classifiers **influence**
later classification decisions.

For example, if **RoadTypeClassifier** identifies **"Avenida" with 0.95 confidence**, the **EuropeanStreetNameClassifier
** knows the following tokens are likely a **street name**.

### 4. Solving with BeamSearch and TopK structure

This is where the magic happens. The solver explores multiple parsing paths simultaneously but keeps only the most promising candidates using a **BeamSearch** algorithm with **TopK pruning**.

[IMAGE: BeamSearch exploring different solutions with confidence scores and top-k candidates at each step]

How the solving process works:


