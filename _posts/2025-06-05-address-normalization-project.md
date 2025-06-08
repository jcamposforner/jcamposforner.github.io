---
title: "Address Parsing at Scale"
description: "Address Parsing at Scale: How Graph Algorithms Beat Regex and ML"
categories: [ Geospatial, Address Normalization, Geocoder ]
tags: [ Geospatial, Address Normalization, Geocoder ]
hidden: false
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

What actually worked was a **graph-based tokenizer** with fuzzy matching.

## Architecture Overview

### 1. Smart Tokenization with Graph Relationships

Instead of treating addresses as strings, we build a **connected graph** of relationships between tokens.

The tokenizer creates three levels:

- **Sections**: Split by commas and known delimiters
- **Words**: Individual tokens within sections
- **Phrases**: Words permutations (max 5 words)

![normalization](/assets/img/address/normalization.png)
_Tokenization flow_

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

This connected structure helps disambiguate tokens.

For example, **"España"** could be part of "**Calle de España (street name), España (country)**".

![graph-tokens](/assets/img/address/graph-tokens.png)
_The graph relationships help the classifier make better decisions._

### 2. Phrase Generation with Sliding Windows

The phrase generator creates all possible combinations up to 5 words using a sliding window approach:

![phrase-diagram](/assets/img/address/phrase-diagram.png)
_Phrase generation_

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
7. **EuropeanStreetNameClassifier**: Uses abbreviation expansion (**"C/" -> "Calle", "Avda" -> "Avenida"**)

![classifiers-pipeline](/assets/img/address/classifiers-queue.png)
_Classification pipeline_

The ordering is **critical** to ensure that tokens identified with high confidence by early classifiers **influence**
later classification decisions.

For example, if **RoadTypeClassifier** identifies **"Avenida" with 0.95 confidence**,
the **EuropeanStreetNameClassifier** knows the following tokens are likely a **street name**.

### 4. Solving with BeamSearch and TopK structure

This is where the magic happens. The solver explores multiple parsing paths simultaneously but keeps only the most
promising candidates using a **BeamSearch** algorithm with **TopK pruning**.

![img-description](/assets/gif/algorithm/beamsearch.gif)
_BeamSearch_

How the solving process works:

1. **TopK**: Maintains only the best candidates at any time using a **min-heap**. This is **crucial**
2. **Iterative Exploration**:

	- Extracts all current candidates from **TopK**
	- Updates the best solution seen so far
	- Expands each candidate
	- Adds new candidates back to TopK

3. **Early Exit**: If any solution reaches the optimal solution (score = 6.0), we return immediately
4. **Fallback**: We return the best candidate inside **TopK**

![img-description](/assets/gif/data-structure/minheap.gif)
_Min heap used for TopK_

#### Key insights from the BeamSearch implementation:

- **Beam Width = 3**: We keep just 5 candidates.
- **Best Solution Tracking**: We keep the best solution ensuring we never lose a good solution, even if it's not in the
  current
  beam.
- **Greedy but Smart**: While BeamSearch is inherently greedy, the combination with our heuristic helps to the best
  solutions.

#### Example

Let's see how BeamSearch works the following address: **Avenida de la Reina María Cristina 34, Spain, Barcelona, 08004**

##### Iteration 1: Processing "Avenida"

```
"Avenida" -> RoadType (score: 1.0)
```

**TopK after iteration 1:**

```
1. ["Avenida"(RoadType: 1.0), next="de"] - Total: 1.0
```

##### Iteration 2: Expanding top candidates

Expanding ["Avenida"(RoadType: 1.0), next="de"]:

```
"de" -> StopWord (score: 0.0)
"de la" -> StopWords (score: 0.0)
"de la Reina" -> EuropeanStreetName (score: 0.5)
"de la Reina María" -> EuropeanStreetName (score: 0.6)
"de la Reina María Cristina" -> EuropeanStreetName (score: 1.0)
```

**TopK after iteration 2:**

_We purge "de" and "de la"_

```
1. ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), next="de"] - Total: 2.0
2. ["Avenida"(RoadType), "Reina María"(EuropeanStreetName), next="Cristina"] - Total: 1.6
3. ["Avenida"(RoadType), "Reina"(EuropeanStreetName), next="María"] - Total: 1.5. 
```

**Iteration 3: Expanding top 3 candidates**

- Expanding candidate ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), next="34"]:

```
"34" -> HouseNumber (score: 1.0)
"34," -> Invalid (no valid classifications)
```

- Expanding candidate 2 ["Avenida"(RoadType), "Reina María"(EuropeanStreetName), next="Cristina"]:

```
"Cristina" -> Cannot add more street names (mask conflict)
"Cristina 34" -> Cannot add more street names (mask conflict)
```

- Expanding candidate 3 ["Avenida"(RoadType), "Reina"(EuropeanStreetName), next="María"]:

```
"María" -> Cannot add more street names (mask conflict)
"María Cristina" -> Cannot add more street names (mask conflict)
```

**TopK after iteration 3:**

```
1. ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), next="Spain"] - Total: 3.0
2. ["Avenida"(RoadType), "Reina María"(EuropeanStreetName), next="34"] - Total: 1.6
3. ["Avenida"(RoadType), "Reina"(EuropeanStreetName), next="Cristina"] - Total: 1.5. 
```

**Iteration 4: Section transition**

Expanding ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), next="Barcelona"]:

```
Spain -> Country (score: 1.0)
```

**TopK after iteration 4:**

```
1. ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), next="Barcelona"] - Total: 4.0
2. ["Avenida"(RoadType), "Reina María"(EuropeanStreetName), "34"(HouseNumber) next="Spain"] - Total: 2.6
3. ["Avenida"(RoadType), "Reina"(EuropeanStreetName), next="34"] - Total: 1.5. 
```

**Iteration 5: Section transition**

Expanding ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), next="08004"]:

```
Barcelona -> City (score: 1.0)
```

**TopK after iteration 5:**

```
1. ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), "Barcelona"(City), next="08004"] - Total: 5.0
2. ["Avenida"(RoadType), "Reina María"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), next="Barcelona"] - Total: 3.6
... lower score solutions but keep adding into it for disambiguate
```

**Iteration 6: Section transition**

Expanding ["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), "Barcelona"(City), next=null]:

```
08004 -> ZipCode (score: 1.0)
```

**TopK after iteration 6:**

```
["Avenida"(RoadType), "Reina María Cristina"(EuropeanStreetName), "34"(HouseNumber), "Spain"(Country), "Barcelona"(City), "08004"(ZipCode), next=""] - Total: 6.0
... lower score solutions but keep adding into it for disambiguate
```

**Final Solution:**

- Avenida -> RoadType (1.0)
- Reina María Cristina -> EuropeanStreetName (1.0)
- 34 -> HouseNumber (1.0)
- Spain -> Country (1.0)
- Barcelona -> City (1.0)
- 08004 -> ZipCode (1.0)

**Total score: 6.0 ( optimal solution )**

### Handling Ambiguous Addresses

Ambiguous addresses are the hard test for any normalization system. They're addresses where the same tokens can
represent multiple different classifications.

Example ["Avenida de España, Mexico"]:

This simple address exposes the core ambiguity problem. **"España"** could be:

- Part of the street name: "Avenida de España"
- A location reference after the street: "Avenida de" + "España" (country)
- With **"Mexico"** potentially being a country

The **BeamSearch** helps to mitigate the ambiguity exploring all paths possible paths:

```
Path 1: ["Avenida"(StreetName), "España"(Country), "Mexico"(Unkown)] - Score: 1.6
Path 2: ["Avenida"(RoadType), "España"(StreetName), "Mexico"(Country)] - Score: 2.8
```

BeamSearch selects the highest scoring path (2.8), which correctly identifies the street structure with country
context. This greedy approach works because our classifiers are tuned to assign higher confidence to common patterns.

## Performance Lessons Learned

Through extensive benchmarking and optimization of the address normalization system, several critical performance
insights emerged:

### Regex Performance Bottlenecks

Regular expressions proved to be a significant performance bottleneck for parsing. While regex
offers flexibility and readability, the performance penalty becomes unacceptable when processing millions of
addresses.


<div style="text-align: center;">
<b>Conditionals has a huge performance improvements over regex.</b>
</div>

### Benchmarking with real data

Synthetic benchmarks failed to capture real-world performance characteristics.

Only by testing with actual edge cases, malformed inputs, and international variations.

<div style="text-align: center;">
<b>Always benchmark with representative datasets.</b>
</div>

### BitMasking for Classification States

Implementing bit masks to track already classified components provided a performance boost. Instead of
maintaining a **HashSets** to check if an address components had already been
identified, a **single integer** with bit operations reduced memory footprint and improved lookup performance.

This technique proved especially valuable when solving **ambiguous** addresses where the same token could match multiple
classification types.

This prevents duplicate classifications and speeds up the "**is this classification slot already taken?**" check that
happens constantly during address solver.

![bit-mask](/assets/img/address/mask.png)
_Bit & operation_

The key takeaway: optimizations matter at scale. What seems negligible when processing single addresses compounds
dramatically when normalizing millions of records.
