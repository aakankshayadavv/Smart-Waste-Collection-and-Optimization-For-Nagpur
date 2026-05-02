import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta


# ============================================================
# 🏙️ DATA ENGINE: NAGPUR MASTER DATA & PRIORITY LOGIC
# ============================================================
@st.cache_data
def load_nagpur_command_data():
    # Load your provided Bins.csv
    df = pd.read_csv('Bins.csv')

    # 1. ASSIGN PRIORITY WEIGHTS (Hospitals & Markets Highest)
    area_weights = {
        'Hospital': 5.0,
        'Market': 4.0,
        'Commercial': 3.0,
        'Residential': 2.0,
        'Industrial': 1.0
    }
    df['Area_Weight'] = df['AreaType'].map(area_weights)
    df['Pop_Score'] = df['PopulationDensity'].map({'Low': 1, 'Medium': 2, 'High': 3})

    # Priority Formula: Heavy focus on Area Type (60%) and Population Density (40%)
    df['Priority_Score'] = (df['Area_Weight'] * 0.6) + (df['Pop_Score'] * 0.4)

    # 2. SIMULATE TELEMETRY (For Forecasts)
    np.random.seed(42)
    df['CurrentFill_%'] = np.random.randint(10, 101, len(df))
    df['FillRate_Hr'] = np.random.uniform(2, 9, len(df))
    df['Hours_Left'] = (100 - df['CurrentFill_%']) / df['FillRate_Hr']
    df['Hours_Left'] = df['Hours_Left'].clip(lower=0)

    return df


df = load_nagpur_command_data()

# ============================================================
# 🛰️ APP INTERFACE & STYLING
# ============================================================
st.set_page_config(page_title="Nagpur Municipal Waste", layout="wide")

# High-contrast CSS for white backgrounds
st.markdown("""
    <style>
    div[data-testid="column"] {
        background-color: #ffffff;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0px 4px 10px rgba(0, 0, 0, 0.05);
        border: 1px solid #eceef2;
    }
    [data-testid="stMetricValue"] { color: #111827; font-weight: 700; }
    .main { background-color: #f9fafb; }
    </style>
    """, unsafe_allow_html=True)

# --- 🏛️ BRANDED HEADER (Logo Integration) ---
col_logo, col_title = st.columns([1, 7])

with col_logo:
    # Uses your provided logo file
    try:
        st.image("nagpur_logo.png", width=105)
    except:
        st.error("Logo 'nagpur_logo.png' not found.")

with col_title:
    st.title("Nagpur Municipal: Smart Waste Command Center")
    st.caption(f"Real-time monitoring of {len(df)} IoT bins across the city registry.")

# --- KPI METRICS ---
m1, m2, m3, m4 = st.columns(4)
critical_alerts = df[(df['AreaType'].isin(['Hospital', 'Market'])) & (df['CurrentFill_%'] > 75)]

with m1: st.metric("Active Bins", len(df))
with m2: st.metric("Hosp/Market Alerts", len(critical_alerts), delta="Urgent", delta_color="inverse")
with m3: st.metric("Avg City Fill", f"{int(df['CurrentFill_%'].mean())}%")
with m4: st.metric("Full < 5 Hours", len(df[df['Hours_Left'] < 5]))

st.divider()

# ============================================================
# 📊 ANALYTICS DASHBOARD
# ============================================================
st.header("Operational Insights")
col_chart1, col_chart2 = st.columns(2)

with col_chart1:
    st.write("### 🏥 Priority Ranking by Area Type")
    # Simplified Column Chart for clear understanding
    avg_priority = df.groupby('AreaType')['Priority_Score'].mean().sort_values(ascending=False).reset_index()
    fig_priority = px.bar(
        avg_priority, x='AreaType', y='Priority_Score',
        color='Priority_Score', color_continuous_scale='Reds',
        text_auto='.1f', title="Weighted Priority (Higher = Pick Up First)"
    )
    fig_priority.update_layout(showlegend=False, coloraxis_showscale=False)
    st.plotly_chart(fig_priority, use_container_width=True)

with col_chart2:
    st.write("### 🫧 Capacity vs. Current Load")
    # Bubble chart to see if large bins (bubbles) are getting full (red)
    fig_bubble = px.scatter(
        df, x='BinID', y='CurrentFill_%', size='Capacity_Ltrs',
        color='CurrentFill_%', hover_name='AreaType',
        color_continuous_scale='RdYlGn_r', title="Bin Size vs. Fill Percentage"
    )
    st.plotly_chart(fig_bubble, use_container_width=True)

# ============================================================
# 🗺️ GEOGRAPHIC VISUALS
# ============================================================
st.divider()
st.header("📍 Advanced City Logistics")
tab1, tab2 = st.tabs(["Waste Density Map", "🚛 Priority Dispatch Path"])

with tab1:
    st.write("### Nagpur Waste Concentration Heatmap")
    fig_heat = px.density_mapbox(
        df, lat='Latitude', lon='Longitude', z='CurrentFill_%', radius=20,
        center=dict(lat=21.1458, lon=79.0882), zoom=11,
        mapbox_style="open-street-map", color_continuous_scale='YlOrRd', height=600
    )
    st.plotly_chart(fig_heat, use_container_width=True)

with tab2:
    st.write("### Recommended Route for Urgent Bins")
    urgent_path = df[df['CurrentFill_%'] > 80].sort_values(by='Priority_Score', ascending=False)
    if not urgent_path.empty:
        fig_route = px.line_mapbox(
            urgent_path, lat="Latitude", lon="Longitude", hover_name="BinID",
            zoom=11, center=dict(lat=21.1458, lon=79.0882), height=600
        )
        fig_route.add_trace(go.Scattermapbox(
            lat=urgent_path['Latitude'], lon=urgent_path['Longitude'],
            mode='markers+text', marker=dict(size=12, color='red'),
            text=urgent_path['BinID'], textposition="top center"
        ))
        fig_route.update_layout(mapbox_style="carto-positron")
        st.plotly_chart(fig_route, use_container_width=True)
    else:
        st.info("No bins currently meet the urgent dispatch threshold (>80% fill).")

# ============================================================
# 🔮 PREDICTION CENTER
# ============================================================
st.divider()
st.header("Predictive Forecast")
c1, c2 = st.columns([1, 2])

with c1:
    selected_bin = st.selectbox("Target a Specific Bin:", df['BinID'])
    bin_row = df[df['BinID'] == selected_bin].iloc[0]

    st.write(f"#### Status for {selected_bin}")
    st.write(f"**Type:** {bin_row['AreaType']} | **Ward:** {bin_row['Ward']}")
    st.progress(int(bin_row['CurrentFill_%']))

    if bin_row['Hours_Left'] <= 5:
        st.error(f"Prediction: This bin will OVERFLOW in **{bin_row['Hours_Left']:.1f} hours**.")
    else:
        st.success(f"Prediction: Safe. Fill time remaining: **{bin_row['Hours_Left']:.1f} hours**.")

with c2:
    st.write("#### Waste Intensity by Nagpur Ward")
    fig_ward = px.bar(
        df, x='Ward', y='CurrentFill_%', color='CurrentFill_%',
        color_continuous_scale='RdYlGn_r', title="Current Load Across Wards"
    )
    st.plotly_chart(fig_ward, use_container_width=True)