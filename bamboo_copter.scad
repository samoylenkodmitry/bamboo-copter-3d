// Parametric hand-spun rotor ("bamboo-copter") for PLA on Bambu Lab A1 Mini
// Standard 2/3-blade rotor with washout, optional tip ring, and planform sweep (curved blades)
// Author: ChatGPT — v3 (fix parser error, fuse to hub, add sweep, cleaner ring)
// License: CC BY 4.0

/*
HOW TO USE
1) Edit parameters below. F6 → Export STL.
2) TIP_RING true makes a thin annulus (not a disk).
3) Blades now have planform sweep (curvature) and start near the hub to ensure fusion.

NOTES
- Low-Re flat plate with linear washout (root→tip pitch).
- Chord from solidity: c = sigma * PI * R / N.
- Built by hulling thin sections along span; sections rotate in Z for sweep.
- Units: millimeters.
*/

// -------------------- PARAMETERS --------------------
// Rotor sizing
R_mm = 120;                 // radius [mm] (<=125 for A1 Mini one-piece)
N_blades = 3;               // 2 or 3
sigma   = 0.10;             // solidity target (0.06..0.12 typical)

// Blade plate + washout
thickness_mm = 1.0;         // blade thickness [mm]
aoa_root_deg = 12;          // angle of attack / pitch at root [deg]
aoa_tip_deg  = 5;           // angle of attack / pitch at tip [deg]
washout_curve = 1.5;        // 1.0=linear, >1 = more twist near tip, <1 = more near root
root_chord_scale = 1.00;    // 1.0 = use sigma chord at root
tip_chord_scale  = 0.80;    // taper (0.7..1.0)
sections = 13;              // longitudinal blade sections (>=7 recommended)
root_frac = 0.08;           // aerodynamic root fraction of R (0.05..0.20)
root_frac = 0.08;           // aerodynamic root fraction of R (0.05..0.20)

// Planform sweep (curvature in top view)
sweep_root_deg = 0;         // sweep angle at root [deg]
sweep_tip_deg  = 12;        // sweep angle at tip [deg]

// Hub / shaft
hub_d_mm   = 12;            // hub outer diameter [mm]
hub_h_mm   = 6;             // hub height [mm]
shaft_hole_d_mm = 4.2;      // through-hole for stick/dowel [mm]
fillet_mm  = 1.0;           // small fillet bump at root

// Tip ring (annulus)
TIP_RING = true;            // add ring connecting tips
ring_width_mm = 4.0;        // radial width of ring [mm]
ring_thick_mm = 1.2;        // ring thickness [mm]
ring_clear_mm = 0.6;        // gap from blade tip to ring inner edge

// Tip weight pockets (optional)
TIP_WEIGHTS = false;
tip_pocket_w = 6.0;         // pocket width [mm]
tip_pocket_h = 1.2;         // depth [mm]
tip_pocket_l = 10.0;        // length [mm]

// -------------------- DERIVED --------------------
c_mm = sigma * 3.14159265359 * R_mm / N_blades; // mean chord from solidity
c_root_mm = c_mm * root_chord_scale;
c_tip_mm  = c_mm * tip_chord_scale;
R_aero_mm = R_mm * 0.985;                         // tiny margin for ring
hub_r_mm  = hub_d_mm/2;
R_root_mm = max(hub_r_mm + 0.6, R_mm*root_frac);  // start just beyond hub so it fuses

$fn = 96; $fa = 6; $fs = 0.5;

// -------------------- HELPERS --------------------
function lerp(a,b,t)=a + (b-a)*t;
function chord_at(u) = lerp(c_root_mm, c_tip_mm, u);
function pitch_at(u) = aoa_root_deg + (aoa_tip_deg - aoa_root_deg) * pow(u, washout_curve);
function radius_at(u)= lerp(R_root_mm, R_aero_mm - ring_clear_mm - 0.25, u); // ensure tip meets ring
function sweep_at(u) = lerp(sweep_root_deg, sweep_tip_deg, u);

module plate_2d(w,l){
    offset(r=0.35) square([max(0.4,w-0.7), max(0.4,l-0.7)], center=true);
}

module blade_section(u){
    c = chord_at(u);
    r = radius_at(u);
    p = pitch_at(u);
    s = sweep_at(u);
    // rotate in Z by sweep, then move out along (rotated) Y, then pitch about local x
    rotate([0,0,s])
        translate([0, r, 0])
            rotate([p,0,0])
                linear_extrude(height=thickness_mm)
                    plate_2d(c, thickness_mm);
}


module blade_loft(){
    union(){
        for(i=[0:sections-2]){
            u0 = i/(sections-1);
            u1 = (i+1)/(sections-1);
            hull(){ blade_section(u0); blade_section(u1); }
        }
        // root fusion bump near hub to guarantee manifold union
        hull(){
            translate([0, R_root_mm-1.0, 0]) cylinder(h=thickness_mm, r=fillet_mm);
            translate([0, hub_r_mm+0.2, 0]) cylinder(h=thickness_mm, r=fillet_mm*0.7);
        }
    }
}

module tip_weight_pocket(){
    if(TIP_WEIGHTS){
        u = 0.95; r = radius_at(u);
        rotate([0,0,sweep_at(u)])
            translate([0, r, thickness_mm*0.5])
                rotate([pitch_at(u),0,0])
                    translate([0,0,-tip_pocket_h])
                        cube([tip_pocket_w, tip_pocket_l, tip_pocket_h], center=true);
    }
}

module blade(){
    // Center blade through hub thickness so it truly fuses with hub and ring
    blade_z0 = (hub_h_mm - thickness_mm)/2; // passes through hub solid
    translate([0,0, blade_z0])
        difference(){
            blade_loft();
            tip_weight_pocket();
        }
}

module hub(){
    difference(){
        cylinder(h=hub_h_mm, d=hub_d_mm);
        translate([0,0,-1]) cylinder(h=hub_h_mm+2, d=shaft_hole_d_mm);
    }
}

module tip_ring(){
    if(TIP_RING){
        Rin = R_aero_mm - ring_clear_mm - ring_width_mm;
        Rout = R_aero_mm - ring_clear_mm;
        // Ring built at same Z as blades so they fuse
        ring_z0 = (hub_h_mm - ring_thick_mm)/2;
        translate([0,0, ring_z0])
            linear_extrude(height=ring_thick_mm)
                difference(){
                    circle(r=Rout);
                    circle(r=max(0.2, Rin));
                }
    }
}

module rotor(){
    union(){
        hub();
        for(k=[0:N_blades-1])
            rotate([0,0, k*360/N_blades]) blade();
        tip_ring();
    }
}

// -------------------- BUILD --------------------
rotor();
