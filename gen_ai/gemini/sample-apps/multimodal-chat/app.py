import streamlit as st

st.set_page_config(
    page_title="Hello",
    page_icon="👋",
)

st.write("# Gemini Demo Series 👋")

st.sidebar.success("Select a demo above.")

st.markdown(
    """
    This app is using Streamlit, an open-source app framework built specifically for
    Machine Learning and Data Science projects.
    **👈 Select a demo from the sidebar** to see some examples
    of what Gemini can do!
    ### Want to learn more?
    - Check other demos in our public [github repository](https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini)
    - Jump into our [documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/models)
"""
)