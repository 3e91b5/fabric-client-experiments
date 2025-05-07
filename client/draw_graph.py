# read from directory ./csv and read recent 3 csv files
# and draw a graph with the data
# 3 csv files are about input key patterns and its storage increase
# the last column is cumulative storage increase
# draw 3 lines with different colors in 1 graph
# there is no need to use elapsed time or timestamp

# calculate the ratio between sequence, random, hash
# and print the result


import os
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime
import matplotlib.ticker as ticker # Y축 포맷팅을 위해 유지


# read csv files from directory
def read_csv_files(directory):
    csv_files = [f for f in os.listdir(directory) if f.endswith('.csv')]
    # 파일 이름에 포함된 패턴(seq, rand, hash) 정보를 추출하여 정렬 기준으로 사용 가능
    # 예: ws-seq-20231027103000-100-1000.csv -> "seq"
    # 파일명 형식: ws-${PAT}-${TIMESTAMP}-${ROUND_STEP}-${TOTAL}.csv
    csv_files.sort(key=lambda x: os.path.getmtime(os.path.join(directory, x)), reverse=True)
    
    return csv_files[:3]

def main(directory_path): # 디렉토리 경로를 인자로 받도록 수정
    csv_files = read_csv_files(directory_path)
    if not csv_files:
        print(f"No CSV files found in {directory_path}")
        return
    
    # 파일 이름에서 패턴명 추출 (범례용)
    # 파일명 형식: ws-${PAT}-${TIMESTAMP}-${ROUND_STEP}-${TOTAL}.csv
    # 예: ws-seq-20231027103000-100-1000.csv -> "seq"
    patterns = []
    for csv_file in csv_files:
        try:
            pattern_name = csv_file.split('-')[1] # 'ws' 다음 부분이 패턴명
            patterns.append(pattern_name.upper()) # 대문자로 표시 (예: SEQ)
        except IndexError:
            patterns.append(os.path.splitext(csv_file)[0]) # 파싱 실패 시 파일명 사용


    graph_file_name = f'graph_{datetime.now().strftime("%Y%m%d_%H%M%S")}.png'
    graph_file_path = os.path.join(directory_path, graph_file_name)
    
    fig, ax = plt.subplots(figsize=(12, 7)) # 그래프 크기 조정
    
    colors = ['green', 'red', 'blue'] # 각 라인별 색상

    # 데이터를 저장할 딕셔너리: key=패턴명, value=DataFrame
    dfs = {}

    for i, csv_file in enumerate(csv_files):
        file_path = os.path.join(directory_path, csv_file)
        try:
            df = pd.read_csv(file_path)
            dfs[patterns[i]] = df # 패턴명을 키로 사용하여 DataFrame 저장

            # CSV 파일의 마지막 열 이름을 사용 (예: 'cumulative_delta_from_pattern_start')
            y_column_name = df.columns[-1] 
            
            # X축은 'count' 열 사용
            x_values = df['count']
            y_values = df[y_column_name]
            
            # plot the data
            ax.plot(x_values, y_values, label=f'{patterns[i]} pattern', marker='o', color=colors[i % len(colors)])
        except Exception as e:
            print(f"Error processing file {csv_file}: {e}")
            continue

    ax.set_title('Cumulative Storage Increase by Key Pattern')
    ax.set_xlabel('Number of Keys (Count)')
    ax.set_ylabel('Cumulative Storage Increase (Bytes)')
    
    # Y축 단위를 K, M, G 등으로 표시 (선택 사항)
    def bytes_formatter(x, pos):
        if x == 0:
            return '0B'
        size_name = ("B", "KB", "MB", "GB", "TB")
        j = 0
        y_val = x
        while y_val >= 1024 and j < len(size_name) -1 :
            y_val /= 1024.0
            j += 1
        return f"{y_val:.1f}{size_name[j]}"

    ax.yaxis.set_major_formatter(ticker.FuncFormatter(bytes_formatter))
    
    ax.legend()
    ax.grid(True) # 그리드 추가
    plt.tight_layout() # 레이아웃 자동 조정
    
    try:
        plt.savefig(graph_file_path)
        print(f'Graph saved to {graph_file_path}')
    except Exception as e:
        print(f"Error saving graph: {e}")
    finally:
        plt.close(fig) # 리소스 해제
    
    # 비율 계산 및 출력
    # count마다 sequ와 random 사이의 비율을 계산
    # dictionary 예: key: {count}, value: {seq /  rand * 100}
    # result example: [0.87, 0.89, 0.96, ...]
    
    # 'SEQ'와 'RAND' 패턴의 데이터프레임 가져오기
    # patterns 리스트에는 대문자로 저장되어 있음
    seq_df = None
    rand_df = None
    short_prefix_df = None

    for pattern_name, df_data in dfs.items():
        if pattern_name == 'SEQU':
            seq_df = df_data
        elif pattern_name == 'RAND':
            rand_df = df_data
        elif pattern_name == 'SHORTPREFIX':
            short_prefix_df = df_data
            
    ratios_by_count = {}
    ratios_list = []

    if seq_df is not None and rand_df is not None:
        # 'count' 열을 기준으로 두 데이터프레임을 병합 (동일한 count 값에 대해 처리하기 위함)
        # 마지막 열(누적 증가량)의 이름이 동일하다고 가정하거나, 명시적으로 지정해야 함
        # 여기서는 각 df의 마지막 열 이름을 사용
        seq_y_col = seq_df.columns[-1]
        rand_y_col = rand_df.columns[-1]

        # 'count'를 기준으로 merge
        merged_df = pd.merge(seq_df[['count', seq_y_col]], rand_df[['count', rand_y_col]], on='count', suffixes=('_seq', '_rand'))

        for index, row in merged_df.iterrows():
            count = int(row['count'])
            seq_val = row[seq_y_col+'_seq']
            rand_val = row[rand_y_col+'_rand']
            
            if rand_val != 0: # 0으로 나누는 경우 방지
                ratio = (seq_val / rand_val) 
                ratios_by_count[count] = ratio * 100 # 백분율로 저장
                ratios_list.append(ratio) # 주석의 예시 형식으로 리스트에도 저장
            else:
                ratios_by_count[count] = float('inf') if seq_val != 0 else 0 # rand가 0일 때 처리
                ratios_list.append(float('inf') if seq_val != 0 else 0)
        
        print("\nRatios (SEQ / RAND * 100) by count:")
        for count, ratio_percent in ratios_by_count.items():
            print(f"Count {count}: {ratio_percent:.2f}%")
            
        print("\nRatios list (SEQ / RAND):")
        print([f"{r:.2f}" for r in ratios_list])
        
    else:
        print("\nCould not calculate ratios: 'SEQ' or 'RAND' pattern data not found.")
    
    if short_prefix_df is not None:
        # 'SHORTPREFIX' 패턴의 데이터프레임을 가져와서 비율 계산
        shortprefix_y_col = short_prefix_df.columns[-1]
        
        # 'count'를 기준으로 seq_df와 short_prefix_df 병합
        merged_short_df = pd.merge(seq_df[['count', seq_y_col]], short_prefix_df[['count', shortprefix_y_col]], on='count', suffixes=('_seq', '_shortprefix'))

        for index, row in merged_short_df.iterrows():
            count = int(row['count'])
            seq_val = row[seq_y_col+'_seq']
            short_val = row[shortprefix_y_col+'_shortprefix'] 
            
            if short_val != 0:
                ratio = (seq_val / short_val) 
                ratios_by_count[count] = ratio * 100
                ratios_list.append(ratio)
            else:
                ratios_by_count[count] = float('inf') if seq_val != 0 else 0
                ratios_list.append(float('inf') if seq_val != 0 else 0)
        print("\nRatios (SEQ / SHORTPREFIX * 100) by count:")
        for count, ratio_percent in ratios_by_count.items():
            print(f"Count {count}: {ratio_percent:.2f}%")
        print("\nRatios list (SEQ / SHORTPREFIX):")
        print([f"{r:.2f}" for r in ratios_list])
    else:
        print("\nCould not calculate ratios: 'SHORTPREFIX' pattern data not found.")
    print("\nRatio calculation finished.")
    

if __name__ == "__main__":
    # 스크립트가 위치한 디렉토리 기준으로 ./csv 디렉토리를 지정
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_directory = os.path.join(script_dir, 'csv')
    main(csv_directory)