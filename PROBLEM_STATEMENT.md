# AI Search for Rally Data

## Overview

Pineamite is building a rally-focused platform containing information about rallies, drivers, results, videos, highlights, and content uploaders.

We want to introduce an AI-powered search experience where users can search using either text or voice/audio input.

Your task is to build a working prototype of this search system.

## Problem Statement

Users should be able to type a query or speak naturally using a microphone and search Pineamite's rally data.
Example searches:
“Show me all rallies that happened in Ireland.”
“Show rallies in Donegal.”
“Find rallies from 2025.”
“Which rallies did Driver X participate in?”
“Which rallies did Driver X win?”
“Who finished first in Rally X?”
“Show the top 10 finishers from Rally X.”
“Show jump highlights from Rally X.”
“Show videos featuring Driver X.”
“Who are the top uploaders for Rally X?”
“Show the drivers with the most wins.”
The search should also understand combinations such as:
“Show rallies in Ireland in 2025 where Driver X participated.”
“Show jump highlights featuring Driver X from Rally Y.”

## Audio-Based Search

The prototype should support voice as a search input.

A user should be able to speak a query such as:

🎙️ “Show me all rallies in Ireland where Driver X competed.”

The system should process the spoken request and perform the same search that would be performed if the query were typed.

We are interested in the end-to-end search experience and accuracy, rather than the visual design of the microphone interface.

## Data

You may use a mock dataset containing:

Rallies and locations
Drivers and rally participation
Rally results and positions
Videos and uploaders
Highlights such as jumps, crashes, podiums, etc.
The dataset should contain enough relationships to demonstrate meaningful searches.

## Search Requirements

The prototype should demonstrate search across:
Rallies — Rally name, location, year, etc.
Drivers — Rallies associated with particular drivers.
Results — Winners, positions, top finishers, and driver performance.
Videos & Highlights — Content associated with rallies and drivers.
Uploaders — Search or rank contributors based on rally content.

The system should also reasonably handle multiple filters, similar names, unknown entities, and ambiguous searches.

## Bonus
Support conversational follow-up searches:
User: Show Donegal Rally 2025.
User: Who won it?
User: Show videos of him.
User: Only show jumps.

## Also consider searches that cannot be answered through simple metadata:
“Show me the biggest jumps.”
“Find exciting moments from Rally X.”

## Deliverables

### Please provide:

Working search prototype supporting text and audio/voice search.
Source code.
Sample/mock dataset.
README with setup instructions and a brief explanation of your approach.
At least 10–15 example queries demonstrating different search capabilities.
A basic UI, API interface, CLI, or similar demonstration is sufficient. Frontend/UI quality is not a primary evaluation criterion.

## Evaluation

### We will primarily evaluate:

Accuracy and relevance of search results.
Natural-language understanding.
Audio/voice search functionality.
Ability to handle different types and combinations of searches.
Handling of ambiguous or unknown queries.
Code quality and maintainability.
Overall quality of the search experience.

The goal is to demonstrate a flexible and reliable AI-powered text and voice search experience for Pineamite's rally data.








