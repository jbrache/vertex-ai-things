# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import streamlit as st

st.set_page_config(
    page_title="Hello",
    page_icon="👋",
)

st.write("# Welcome to Gemini Function Calling! 👋")

st.sidebar.success("Select a demo above.")

st.markdown(
    """
    ### What is function calling in Gemini?
    The [Vertex AI Gemini API](https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/overview)
    is a family of generative AI models developed by Google DeepMind that is designed 
    for multimodal use cases. [Function calling](https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling)
    is a feature of Gemini models that makes it easier for developers to get structured
    data outputs from generative models.

    Developers can then use these outputs to call other APIs and return
    the relevant response data to the model. In other words, function
    calling helps you connect your generative models to external systems
    so that the generated content includes the most up-to-date and accurate
    information.

    **👈 Select a demo from the sidebar** to see some examples of what function calling in Gemini can do!

    ### How function calling works
    Functions are described using function declarations, which helps the generative model
    understand the purpose and parameters within a function. After you pass function
    declarations in a query to a generative model, the model returns a structured object
    that includes the names of relevant functions and their arguments based on the user's query.
    Note that with function calling, the model doesn't actually call the function. Instead, you
    can use the returned function and parameters to call the function in any language, library,
    or framework that you'd like!
    """
)

st.image('images/gemini-function-calling-overview_1440.png', caption=None, width=None, use_column_width=None, clamp=False, channels="RGB", output_format="auto")

st.markdown(
    """
    ### Want to learn more?
    - Check it out on YouTube: [Function Calling in Gemini: A Framework for Connecting LLMs to Real-Time Data](https://www.youtube.com/watch?v=gyOTxdULtIw)
    - Jump into our [documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling)
    - Join, learn, and get your questions answered with the [Google Cloud AI Community](https://goo.gle/ai-community)
    ### See more complex demos
    - Codelab on [How to Interact with APIs Using Function Calling in Gemini](https://codelabs.developers.google.com/codelabs/gemini-function-calling)
    - Codelab on [How to Use Cloud Run with Gemini Function Calling](https://codelabs.developers.google.com/codelabs/how-to-cloud-run-gemini-function-calling)
    - Explore a [sample notebook](https://github.com/GoogleCloudPlatform/generative-ai/blob/main/gemini/function-calling/intro_function_calling.ipynb)
    - Side by side comparisons of [function calling in Gemini](https://gemini-function-calling.web.app/)
    """
)

st.markdown(
    """
    Kudos to [Kristopher Overholt](https://github.com/koverholt) and [Param Singh](https://github.com/paramrsingh) 🙌 for making this sample possible!
    """
)
