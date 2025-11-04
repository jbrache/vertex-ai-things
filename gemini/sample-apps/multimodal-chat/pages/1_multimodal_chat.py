import streamlit as st
import os
from PIL import Image
from audio_recorder_streamlit import audio_recorder
from streamlit_pdf_viewer import pdf_viewer
import base64
from io import BytesIO
import google.generativeai as genai
from google.generativeai.protos import (
    Part as GooglePart,
    Content as GoogleContent,
)
import random

import pathlib
import vertexai
from vertexai.generative_models import (
    GenerationConfig,
    GenerativeModel,
    Image as VertexImage,
    SafetySetting,
    FinishReason,
    Content,
    Part,
)
from google.cloud import texttospeech
import emoji

# PROJECT_ID = "the-foo-bar"
REGION = "us-central1"
LOCATION = str(REGION)

# vertexai.init(project=PROJECT_ID, location=LOCATION)

anthropic_models = [
    "claude-3-5-sonnet-20240620"
]

google_models = [
    "gemini-1.5-flash",
    "gemini-1.5-pro",
]

vertexai_models = [
    "vertexai-gemini-1.5-flash",
    "vertexai-gemini-1.5-pro",
]

# Function to convert the messages format from Streamlit to Gemini
def messages_to_gemini(messages):
    gemini_messages = []
    prev_role = None
    for message in messages:
        if prev_role and (prev_role == message["role"]):
            gemini_message = gemini_messages[-1]
        else:
            gemini_message = {
                "role": "model" if message["role"] == "assistant" else "user",
                "parts": [],
            }

        for content in message["content"]:
            if content["type"] == "text":
                gemini_message["parts"].append(content["text"])
            elif content["type"] == "image_url":
                gemini_message["parts"].append(base64_to_image(content["image_url"]["url"]))
            elif content["type"] == "video_file":
                file_upload = content["genai_file"]
                gemini_message["parts"].append(file_upload)
            elif content["type"] == "audio_file":
                file_upload = content["genai_file"]
                gemini_message["parts"].append(file_upload)

        if prev_role != message["role"]:
            gemini_messages.append(gemini_message)

        prev_role = message["role"]
        
    return gemini_messages

# Function to convert the messages format from Streamlit to Gemini
def messages_to_vertexai_gemini(messages):
    gemini_messages = []
    prev_role = None
    for message in messages:
        if prev_role and (prev_role == message["role"]):
            gemini_message = gemini_messages[-1]
        else:
            gemini_message = {
                "role": "model" if message["role"] == "assistant" else "user",
                "parts": [],
            }

        for content in message["content"]:
            if content["type"] == "text":
                gemini_message["parts"].append(Part.from_text(content["text"]))
            elif content["type"] == "image_url":
                gemini_message["parts"].append(Part.from_data(
                    mime_type=message["content"][0]["image_url"]["url"].split(";")[0].split(":")[1],
                    data=message["content"][0]["image_url"]["url"].split(",")[1]
                    )
                )
            elif content["type"] == "video_file":
                file = content["video_file"]
                # with open(file, "rb") as binary_file:
                #     binary_file_data = binary_file.read()
                #     base64_encoded_data = base64.b64encode(binary_file_data)
                #     base64_output = base64_encoded_data.decode('utf-8')

                data_bytes = pathlib.Path(file).read_bytes()

                gemini_message["parts"].append(Part.from_data(
                    mime_type=f"video/{file.split('.')[-1]}",
                    data=data_bytes
                    )
                )

            elif content["type"] == "audio_file":
                file = content["audio_file"]
                # with open(file, "rb") as binary_file:
                #     binary_file_data = binary_file.read()
                #     base64_encoded_data = base64.b64encode(binary_file_data)
                #     base64_output = base64_encoded_data.decode('utf-8')
                
                data_bytes = pathlib.Path(file).read_bytes()

                gemini_message["parts"].append(Part.from_data(
                    mime_type=f"audio/{file.split('.')[-1]}",
                    data=data_bytes
                    )
                )
            elif content["type"] == "pdf_file":
                file = content["pdf_file"]
                # with open(file, "rb") as binary_file:
                #     binary_file_data = binary_file.read()
                #     base64_encoded_data = base64.b64encode(binary_file_data)
                #     base64_output = base64_encoded_data.decode('utf-8')
                
                data_bytes = pathlib.Path(file).read_bytes()

                gemini_message["parts"].append(Part.from_data(
                    mime_type=f"application/{file.split('.')[-1]}",
                    data=data_bytes
                    )
                )


        if prev_role != message["role"]:
            gemini_messages.append(gemini_message)

        prev_role = message["role"]
        
    return gemini_messages


# Function to convert the messages format from Streamlit to Anthropic (the only difference is in the image messages)
def messages_to_anthropic(messages):
    anthropic_messages = []
    prev_role = None
    for message in messages:
        if prev_role and (prev_role == message["role"]):
            anthropic_message = anthropic_messages[-1]
        else:
            anthropic_message = {
                "role": message["role"] ,
                "content": [],
            }
        if message["content"][0]["type"] == "image_url":
            anthropic_message["content"].append(
                {
                    "type": "image",
                    "source":{   
                        "type": "base64",
                        "media_type": message["content"][0]["image_url"]["url"].split(";")[0].split(":")[1],
                        "data": message["content"][0]["image_url"]["url"].split(",")[1]
                        # f"data:{img_type};base64,{img}"
                    }
                }
            )
        else:
            anthropic_message["content"].append(message["content"][0])

        if prev_role != message["role"]:
            anthropic_messages.append(anthropic_message)

        prev_role = message["role"]
        
    return anthropic_messages


# Function to query and stream the response from the LLM
def stream_llm_response(model_params, model_type="google", api_key=None):
    response_message = ""

    if model_type == "google":
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name = model_params["model"],
            generation_config={
                "temperature": model_params["temperature"] if "temperature" in model_params else 0.3,
            }
        )

        gemini_messages = messages_to_gemini(st.session_state.messages)

        if len(gemini_messages) <= 1:
            chat = model.start_chat()
        else:
            chat = model.start_chat(
                history = [{"role":message["role"], "parts":message["parts"]} for message in gemini_messages[:-1]]
            )

        for chunk in chat.send_message(
            content=gemini_messages[-1]["parts"],
            stream=True,
        ):
            chunk_text = chunk.text or ""
            response_message += chunk_text
            yield chunk_text
    
    elif model_type == "google-vertexai":
        model = GenerativeModel(
            model_params["model"].replace("vertexai-", ""),
        )

        generation_config = {
            "temperature": model_params["temperature"] if "temperature" in model_params else 0.3,
        }

        safety_settings = [
            SafetySetting(
                category=SafetySetting.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
                threshold=SafetySetting.HarmBlockThreshold.BLOCK_ONLY_HIGH
                # threshold=SafetySetting.HarmBlockThreshold.BLOCK_NONE
            ),
            SafetySetting(
                category=SafetySetting.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
                threshold=SafetySetting.HarmBlockThreshold.BLOCK_ONLY_HIGH
                # threshold=SafetySetting.HarmBlockThreshold.BLOCK_NONE
            ),
            SafetySetting(
                category=SafetySetting.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
                threshold=SafetySetting.HarmBlockThreshold.BLOCK_ONLY_HIGH
                # threshold=SafetySetting.HarmBlockThreshold.BLOCK_NONE
            ),
            SafetySetting(
                category=SafetySetting.HarmCategory.HARM_CATEGORY_HARASSMENT,
                threshold=SafetySetting.HarmBlockThreshold.BLOCK_ONLY_HIGH
                # threshold=SafetySetting.HarmBlockThreshold.BLOCK_NONE
            ),
        ]
    
        gemini_messages = messages_to_vertexai_gemini(st.session_state.messages)

        if len(gemini_messages) <= 1:
            chat = model.start_chat()
        else:
            chat = model.start_chat(
                history = [Content(role=message["role"], parts=message["parts"]) for message in gemini_messages[:-1]]
            )

        for chunk in chat.send_message(
            content=gemini_messages[-1]["parts"],
            generation_config=generation_config,
            safety_settings=safety_settings,
            stream=True,
        ):
            chunk_text = chunk.text or ""
            response_message += chunk_text
            yield chunk_text

    st.session_state.messages.append({
        "role": "assistant", 
        "content": [
            {
                "type": "text",
                "text": response_message,
            }
        ]})


# Function to convert file to base64
def get_image_base64(image_raw):
    buffered = BytesIO()
    image_raw.save(buffered, format=image_raw.format)
    img_byte = buffered.getvalue()

    return base64.b64encode(img_byte).decode('utf-8')

def file_to_base64(file):
    with open(file, "rb") as f:

        return base64.b64encode(f.read())

def base64_to_image(base64_string):
    base64_string = base64_string.split(",")[1]
    
    return Image.open(BytesIO(base64.b64decode(base64_string)))

def genai_upload_file(file):
    # https://ai.google.dev/api/files#video
    file_upload = genai.upload_file(file)

    # Videos need to be processed before you can use them.
    while file_upload.state.name == "PROCESSING":
        print("processing file...")
        # time.sleep(5)
        file_upload = genai.get_file(file_upload.name)
    
    if file_upload.state.name == "FAILED":
        raise ValueError(file_upload.state.name)
    
    return file_upload

def main():
    # --- Page Config ---
    st.set_page_config(
        page_title="Multimodal Chat",
        page_icon="🤖",
        layout="centered",
        initial_sidebar_state="expanded",
    )

    # --- Header ---
    st.html("""<h1 style="text-align: center; color: #6ca395;">🤖 <i>Multimodal Chat</i> 💬</h1>""")

    # --- Side Bar ---
    with st.sidebar:
        default_google_api_key = os.getenv("GOOGLE_API_KEY") if os.getenv("GOOGLE_API_KEY") is not None else ""  # only for development environment, otherwise it should return None

        with st.popover("🔐 Google"):
            google_api_key = st.text_input("Introduce your Google API Key (https://aistudio.google.com/app/apikey)", value=default_google_api_key, type="password")
     
        # Checking if the user has introduced an API Key, if not, a warning is displayed
        if (google_api_key == "" or google_api_key is None):
            # st.write("#")
            st.warning("⬆️ Please introduce an API Key to have extra model options...")
    
    # --- Main Content --- 
    if "messages" not in st.session_state:
        st.session_state.messages = []

    if "text_in_history" not in st.session_state: # Only used for Google Vertex AI Gemini models
        st.session_state.text_in_history = False

    # Displaying the previous messages if there are any
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            for content in message["content"]:
                if content["type"] == "text":
                    st.write(content["text"])
                elif content["type"] == "image_url":      
                    st.image(content["image_url"]["url"])
                elif content["type"] == "video_file":
                    st.video(content["video_file"])
                elif content["type"] == "pdf_file":
                    pdf_viewer(input=content["pdf_file"], width=700)
                elif content["type"] == "audio_file":
                    st.audio(content["audio_file"])

    # Side bar model options and inputs
    with st.sidebar:
        st.divider()
        
        available_models = [] + (google_models if google_api_key else []) + (vertexai_models)
        model = st.selectbox("Select a model:", available_models, index=0)
        model_type = None
        if model.startswith("gemini"): model_type = "google"
        elif model.startswith("vertexai"): model_type = "google-vertexai"
        
        with st.popover("⚙️ Model parameters"):
            model_temp = st.slider("Temperature", min_value=0.0, max_value=2.0, value=0.3, step=0.1)

        audio_response = st.toggle("Audio response", value=False)
        if audio_response:
            cols = st.columns(2)
            if model_type == "google" or model_type == "google-vertexai":
                with cols[0]:
                    # https://cloud.google.com/text-to-speech/docs/voice-types
                    # https://cloud.google.com/text-to-speech/docs/voices
                    tts_voice = st.selectbox("Select a voice:", [ "Studio", "Journey"])
                with cols[1]:
                    if tts_voice == "Journey":
                        tts_voice_name = ["en-US-Journey-F", "en-US-Journey-D", "en-US-Journey-O"]
                    elif tts_voice == "Studio":
                        tts_voice_name = ["en-US-Studio-O", "en-US-Studio-Q"]
                    tts_model = st.selectbox("Select a model:", tts_voice_name)

        model_params = {
            "model": model,
            "temperature": model_temp,
        }

        def reset_conversation():
            if "messages" in st.session_state and len(st.session_state.messages) > 0:
                st.session_state.pop("messages", None)
   
            st.session_state.text_in_history = False

        st.button(
            "🗑️ Reset conversation", 
            on_click=reset_conversation,
        )

        st.divider()

        # Image Upload
        if model in ["gemini-1.5-flash", "gemini-1.5-pro", "vertexai-gemini-1.5-flash", "vertexai-gemini-1.5-pro"]:
                
            st.write(f"### **🖼️ Add an image{' or a video file' if (model_type=='google' or model_type=='google-vertexai') else ''}:**")

            def add_image_to_messages():
                if st.session_state.uploaded_img or ("camera_img" in st.session_state and st.session_state.camera_img):
                    img_type = st.session_state.uploaded_img.type if st.session_state.uploaded_img else "image/jpeg"
                    
                    mime_type = img_type.split("/")[0]
                    mime_format = img_type.split("/")[1]
                    
                    if mime_type == "video":
                        file_type = st.session_state.uploaded_img.name.split(".")[-1]
                        # save the video file
                        video_id = random.randint(100000, 999999)
                        file_name = f"video_{video_id}.{file_type}"

                        with open(file_name, "wb") as f:
                            f.write(st.session_state.uploaded_img.read())
                        
                        if model_type=='google':
                            # https://ai.google.dev/api/files#video
                            file_upload = genai_upload_file(file_name)
                        else:
                            file_upload = None

                        st.session_state.messages.append(
                            {
                                "role": "user", 
                                "content": [{
                                    "type": "video_file",
                                    "video_file": file_name,
                                    "genai_file": file_upload
                                }]
                            }
                        )
                    elif mime_type == "audio":
                        file_type = st.session_state.uploaded_img.name.split(".")[-1]
                        # save the audio file
                        audio_id = random.randint(100000, 999999)
                        file_name = f"audio_{audio_id}.{file_type}"

                        with open(file_name, "wb") as f:
                            f.write(st.session_state.uploaded_img.read())

                        if model_type=='google':
                            # https://ai.google.dev/api/files#video
                            file_upload = genai_upload_file(file_name)
                        else:
                            file_upload = None

                        st.session_state.messages.append(
                            {
                                "role": "user", 
                                "content": [{
                                    "type": "audio_file",
                                    "audio_file": file_name,
                                    "genai_file": file_upload
                                }]
                            }
                        )
                    elif mime_type == "application":
                        file_type = st.session_state.uploaded_img.name.split(".")[-1]
                        # save the pdf file
                        pdf_id = random.randint(100000, 999999)
                        file_name = f"pdf_{pdf_id}.{file_type}"

                        with open(file_name, "wb") as f:
                            f.write(st.session_state.uploaded_img.read())

                        st.session_state.messages.append(
                            {
                                "role": "user", 
                                "content": [{
                                    "type": "pdf_file",
                                    "pdf_file": file_name,
                                }]
                            }
                        )
                    else:
                        raw_img = Image.open(st.session_state.uploaded_img or st.session_state.camera_img)
                        img = get_image_base64(raw_img)
                        st.session_state.messages.append(
                            {
                                "role": "user", 
                                "content": [{
                                    "type": "image_url",
                                    "image_url": {"url": f"data:{img_type};base64,{img}"}
                                }]
                            }
                        )

            cols_img = st.columns(2)

            with cols_img[0]:
                with st.popover("📁 Upload"):
                    default_types = ["png", "jpg", "jpeg"]

                    # https://ai.google.dev/gemini-api/docs/prompting_with_media?lang=python
                    google_image_types = ["png", "jpg", "jpeg", "webp", "heic", "heif"]
                    google_video_types = ["mp4", "mpeg", "mov", "avi", "x-flv", "mpg", "webm", "wmv", "3gpp"]
                    google_audio_types = ["wav", "mp3", "aiff", "aac", "ogg", "flac"]

                    # https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/video-understanding
                    google_vertexai_image_types = ["png", "jpg", "jpeg"]
                    google_vertexai_video_types = ["x-flv", "mov", "mpeg", "mpegps", "mpg", "mp4", "webm", "wmv", "3gpp"]
                    google_vertexai_audio_types = ["aac", "flac", "mp3", "m4a", "mpeg", "mpga", "mp4", "opus", "pcm", "wav", "webm"]
                    google_vertexai_doc_types = ["pdf"]

                    if model_type=='google':
                        types = set(default_types + google_image_types + google_video_types + google_audio_types)
                    elif model_type=='google-vertexai':
                        types = set(default_types + google_vertexai_image_types + google_vertexai_video_types + google_vertexai_audio_types + google_vertexai_doc_types)
                    else:
                        types = default_types

                    st.file_uploader(
                        f"Upload an image{' or a video' if (model_type=='google' or model_type=='google-vertexai') else ''}:", 
                        type=types, 
                        accept_multiple_files=False,
                        key="uploaded_img",
                        on_change=add_image_to_messages,
                    )

            with cols_img[1]:                    
                with st.popover("📸 Camera"):
                    activate_camera = st.checkbox("Activate camera")
                    if activate_camera:
                        st.camera_input(
                            "Take a picture", 
                            key="camera_img",
                            on_change=add_image_to_messages,
                        )

        # Audio Upload
        st.write("#")
        st.write(f"### **🎤 Add an audio{' (Speech To Text)' if (model_type == 'google' or model_type == 'google-vertexai') else ''}:**")

        audio_prompt = None
        audio_file_added = False
        if "prev_speech_hash" not in st.session_state:
            st.session_state.prev_speech_hash = None

        speech_input = audio_recorder("Press to talk:", icon_size="3x", neutral_color="#6ca395", )
        if speech_input and st.session_state.prev_speech_hash != hash(speech_input):
            st.session_state.prev_speech_hash = hash(speech_input)
            if model_type == "google" or model_type == "google-vertexai":
                # save the audio file
                audio_id = random.randint(100000, 999999)
                with open(f"audio_{audio_id}.wav", "wb") as f:
                    f.write(speech_input)

                st.session_state.messages.append(
                    {
                        "role": "user", 
                        "content": [{
                            "type": "audio_file",
                            "audio_file": f"audio_{audio_id}.wav",
                        }]
                    }
                )

                audio_file_added = True

        # st.divider()
        # st.write("Kudos to this [repo](https://github.com/enricd/the_omnichat) 👏 for inspiration!")

    # Chat input
    if prompt := st.chat_input("Hi! Ask me anything...") or audio_prompt or audio_file_added:
        if not audio_file_added:
            st.session_state.messages.append(
                {
                    "role": "user", 
                    "content": [{
                        "type": "text",
                        "text": prompt or audio_prompt,
                    }]
                }
            )
            
            # Display the new messages
            with st.chat_message("user"):
                st.markdown(prompt)

        else:
            # Display the audio file
            with st.chat_message("user"):
                st.audio(f"audio_{audio_id}.wav")
        
        # At the beginning of the conversation, for Vertex AI Gemini models, the message needs to contain text as of Aug '24 otherwise
        # This error will be displayed:
        #   google.api_core.exceptions.InvalidArgument: 400 Unable to submit request because it must have a text parameter. Add a text parameter and try again.
        #   Learn more: https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/gemini

        if st.session_state.text_in_history == False and model_type == "google-vertexai":
            if st.session_state.messages[-1]["content"][0]["type"] != "text":
                prompt_text = "Follow the instructions in the file to generate a response."
                st.session_state.messages.append(
                    {
                        "role": "user", 
                        "content": [{
                            "type": "text",
                            "text": prompt_text,
                        }]
                    }
                )
                    
                # Display the new messages
                with st.chat_message("user"):
                    st.markdown(prompt_text)

            st.session_state.text_in_history = True

        with st.chat_message("assistant"):
            model2key = {
                "google": google_api_key,
                "google-vertexai": None,
            }
            st.write_stream(
                stream_llm_response(
                    model_params=model_params, 
                    model_type=model_type, 
                    api_key=model2key[model_type]
                )
            )

        # --- Added Audio Response (optional) ---
        if audio_response:
            if model_type == "google" or model_type == "google-vertexai":
                clean_text = emoji.replace_emoji(st.session_state.messages[-1]["content"][0]["text"], '')
                
                tts_client = texttospeech.TextToSpeechClient()
                synthesis_input = texttospeech.SynthesisInput(text=clean_text)
                voice = texttospeech.VoiceSelectionParams(
                    language_code="en-US",
                    name=tts_model,
                )

                audio_config = texttospeech.AudioConfig(
                    audio_encoding=texttospeech.AudioEncoding.LINEAR16,
                    speaking_rate=1
                )

                response = tts_client.synthesize_speech(
                    input=synthesis_input,
                    voice=voice,
                    audio_config=audio_config
                )
                audio_base64 = base64.b64encode(response.audio_content).decode('utf-8')

            audio_html = f"""
            <audio controls autoplay>
                <source src="data:audio/wav;base64,{audio_base64}" type="audio/mp3">
            </audio>
            """
            st.html(audio_html)

if __name__=="__main__":
    main()