# System Usability Scale (SUS) – Survey Description

## Overview

The System Usability Scale (SUS) is a standardized 10-item questionnaire used to evaluate perceived usability of a system. It produces a score ranging from 0 to 100.

The SUS survey for CampusGuide has been implemented using Google Forms.

## Survey Structure

- 10 standardized SUS questions
- 5-point Likert scale (1 = Strongly Disagree, 5 = Strongly Agree)
- Additional open-ended feedback questions
- Optional demographic information

## SUS Scoring Method

For odd-numbered questions (1, 3, 5, 7, 9):
Contribution = Response − 1

For even-numbered questions (2, 4, 6, 8, 10):
Contribution = 5 − Response

Final SUS Score = (Sum of contributions) × 2.5

## Score Interpretation

- 80+ → Excellent usability
- 68 → Industry average
- Below 68 → Needs improvement
- Below 50 → Poor usability

## Usage in This Project

SUS results will be collected after each usability testing session.
Aggregate SUS scores will be analyzed in Sprint 5 and compared before and after UI improvements.
