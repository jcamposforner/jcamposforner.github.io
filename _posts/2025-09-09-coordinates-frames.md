---
title: "Navigation Systems: Why Coordinate Frames Matter"
description: "A simple point like (10,0,0) means nothing until we define its coordinate frame. Learn why navigation always needs reference frames, and how objects are described relative to them."
categories: [ Navigation, Coordinate Frames ]
tags: [ Navigation, Coordinate Systems, Reference Frames, Body Frame, NED, Orientation, Position, Geospatial ]
hidden: false
---

## Why a Point Means Nothing Without Context

![point-position](/assets/img/navigation/coordinates-frames/point-coordinates-frame.png)
<center><em>What does it mean to you?</em></center>

- A person 10 meters in front?
- A landmark 10 meters to the north?
- A coordinate somewhere on the planet?

**We don't know yet.**

Those three numbers are meaningless until we specify **which coordinate frame they're expressed in**.

## What Exactly Is Navigation Trying To Tell Us?

Navigation describes position, orientation, heading, and motion of objects. An object may be a GNSS antenna or an INS,
it may be a vehicle, satellite, a person, animal...

But here's the first challenge: **Where exactly on that object are we measuring?**

To describe the position and motion of an object, a specific point on that object must be selected. This is known as the
origin of that object. It may be the center of mass of that object or an arbitrarily convenient point, such as a corner.

And another challenge: **How do we describe which way it's facing?**

To describe the orientation and angular motion of an object, a set of three orthogonal axes must be selected.

## The Fundamental Problem: Everything Is Relative

Position, orientation and motion of an object are meaningless on their own. Some reference is needed, relative to which
the object may be described. The reference is also defined by an origin and a set of axes. Suitable origins include the
center of the Earth, the center of the solar system, or local landmarks.

If I tell you "I'm 5 meters away,", **"5 meters away from what?"**

But if we had agreed to meet at a specific landmark then **"5 meters away"** makes sense, that's a reference frame.

Now that we can understand why those numbers are meaningless. Let's see what happens when we add context:

![frd-ned](/assets/img/navigation/coordinates-frames/frd-ned.png)

**If (10, 0, 0) is in your vehicle's Body Frame:**

- 10 meters forward
- 0 meters to the right
- 0 meters downward

Result: An obstacle directly ahead.

**If (10, 0, 0) is in a North-East-Down (NED) frame:**

- 10 meters north
- 0 meters east
- 0 meters down (at ground level)

Same numbers, completely different reality.

## Navigation Language

**A bearing** is the angle within the horizontal plane between the line of sight to an object and a known direction,
usually geodetic north. Also called azimuth when the angle is based on the geodetic north.

**Attitude** describes the orientation of the axes of one coordinate frame with respect to another.

**Rotation** describes how attitude changes over time, measured as angular velocities around each axis.

**Landmarks** serve as reference points with known positions that help establish local coordinate frames.

![attitude](/assets/img/navigation/coordinates-frames/attitude.png)
<center><em>Attitude</em></center>

## Navigation problems involves at least two coordinate frames

**Scenario 1: Use only global coordinates (like WGS-84)**

- Problem: How do you know which way your vehicle is pointing?
- Problem: Where exactly is that obstacle 2 meters in front of you?
- Problem: How do sensors mounted on your vehicle report what they see?

**Scenario 2: Use only your vehicle's local frame**

- Problem: How do you navigate to a city 500 km away?
- Problem: How do you share your location with others?
- Problem: How do you use GPS satellites that don't know about your local frame?

The reality: **Navigation is about translation.** We need multiple frames and the ability to convert between them.

## The Mathematical Foundation: How Frames Actually Work

![right-hand-convention](/assets/img/navigation/coordinates-frames/right-hand-rule.jpeg)
<center><em>Right-handed Convention</em></center>
<br/>

The coordinate frame has 6 degrees of freedom. These are the position of the origin **o** and the orientation of the
axes, x, y and z.

In the right-handed convention, the x, y and z axes are always oriented such that if the thumb is the x axis, the first
finger is the y axis and the second finger is the z axis. The opposite convention is left-handed convention that is
rarely used. All frames considered in these posts are both orthogonal and follow the right-handed convention.

Here's the key insight: **Any navigation problem involves at least two coordinate frames.** These are the object frame,
describing the body whose position and orientation is desired, and the reference frame, describing a known body, such as
the Earth, relative to which the object position and orientation is described. However, many navigation problems need
more than one reference frame, for example, inertial space.

## So What's Next?

Now you understand why that simple **P(10, 0, 0)** caused so much confusion. Every number in navigation is meaningless
without its frame of reference.

But which frames should you actually use? And how do you translate between them?

**Next up: We'll learn about [Body Frame (FRD)](/posts/body-frames/){:target="_blank"}**, the coordinate system closest to your object and the way onboard
sensors sees the world around them.
