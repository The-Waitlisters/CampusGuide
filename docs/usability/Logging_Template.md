# Usability Testing Logging Template

## Overview

A structured logging sheet has been created using Google Sheets to record quantitative usability metrics during testing sessions.

## Recorded Metrics

- Participant ID
- Task number
- Start time
- End time
- Automatically calculated task duration (in seconds)
- Number of observed errors
- Task completion status (Yes/No)
- Moderator notes

## Duration Calculation

Duration (seconds) is calculated using:

=(End Time - Start Time) \* 86400

This converts time difference into seconds.

## Summary Calculations

The logging sheet supports automatic computation of:

- Average task time
- Task completion rate
- Average error rate

These metrics will be analyzed during Sprint 5.
